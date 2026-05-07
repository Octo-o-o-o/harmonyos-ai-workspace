#!/usr/bin/env bash
# check-rename-module.sh — 校验鸿蒙多模块工程的模块名 3 处一致
#
# 鸿蒙模块名同时记录在：
#   1. <root>/build-profile.json5         modules[].name
#   2. <module>/src/main/module.json5     module.name
#   3. <module>/oh-package.json5          name（被其他模块用 @ohos/<这个> 引用）
#
# 漏改任一处 → build 失败或运行时找不到模块。本脚本对照三处。
#
# 用法：
#   bash tools/check-rename-module.sh                  # 默认在当前目录跑
#   bash tools/check-rename-module.sh /path/to/app
#
# 退出码：
#   0  全部一致
#   1  发现不一致（命名漂移 / 缺失字段）

set -u

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
err()  { printf "${RED}[✗]${NC} %s\n" "$*"; }
info() { printf "${BLUE}[i]${NC} %s\n" "$*"; }

ROOT="${1:-.}"
ROOT="$(cd "$ROOT" && pwd)"

if [[ ! -f "$ROOT/build-profile.json5" ]]; then
  err "$ROOT/build-profile.json5 不存在；这不像鸿蒙工程根目录"
  exit 64
fi

# json5 比 json 容忍（注释、单引号、尾逗号）
# 用 sed 做简单的 json5 → json 转换：
#   - 删除 // 行注释（行尾后）
#   - 删除 } 和 ] 前的尾逗号（DevEco 默认模板的 build-profile.json5 含
#     `buildModeSet: [{ name: 'debug', }, ...]` 这种合法 JSON5 但非法 JSON）
#   - 不动单引号（jq 在多数情况能容忍）
json5_to_json() {
  sed -e 's|//[^"]*$||g' \
      -e 's/,\([[:space:]]*[}]\)/\1/g' \
      -e 's/,\([[:space:]]*[]]\)/\1/g' \
      "$1"
}

# 提取 build-profile.json5 中所有 modules[].name
extract_profile_modules() {
  if command -v jq >/dev/null 2>&1; then
    json5_to_json "$ROOT/build-profile.json5" 2>/dev/null | jq -r '.modules[]?.name // empty' 2>/dev/null
  else
    # jq 不在 PATH：用 grep/sed 兜底
    grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' "$ROOT/build-profile.json5" | \
      sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | \
      sort -u
  fi
}

# 提取 module.json5 中 module.name
extract_module_name() {
  local f="$1"
  if command -v jq >/dev/null 2>&1; then
    json5_to_json "$f" | jq -r '.module.name // empty' 2>/dev/null
  else
    grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' "$f" | \
      head -1 | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
  fi
}

# 提取 oh-package.json5 中 name
extract_pkg_name() {
  local f="$1"
  if command -v jq >/dev/null 2>&1; then
    json5_to_json "$f" | jq -r '.name // empty' 2>/dev/null
  else
    grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' "$f" | \
      head -1 | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
  fi
}

# ─── 主流程 ──────────────────────────────────────────────────

info "工程根：$ROOT"
profile_modules=$(extract_profile_modules)
if [[ -z "$profile_modules" ]]; then
  err "build-profile.json5 中读不到 modules[].name"
  exit 1
fi

# 找所有可能的模块目录（含 module.json5 的）
mapfile -t module_dirs < <(find "$ROOT" -name 'module.json5' -path '*/src/main/module.json5' -not -path '*/build/*' -not -path '*/oh_modules/*' 2>/dev/null | sort)

failed=0
checked=0

while IFS= read -r profile_name; do
  [[ -z "$profile_name" ]] && continue
  checked=$((checked + 1))

  # 在 module_dirs 里找匹配的（或最可能匹配的）
  found=""
  for mj in "${module_dirs[@]}"; do
    mod_dir=$(dirname "$(dirname "$(dirname "$mj")")")    # ../../..
    pkg_file="$mod_dir/oh-package.json5"
    [[ ! -f "$pkg_file" ]] && continue

    module_name=$(extract_module_name "$mj")
    pkg_name=$(extract_pkg_name "$pkg_file")

    # build-profile 的 name 跟 module.json5 的 module.name 期望相等
    if [[ "$profile_name" == "$module_name" ]]; then
      found="$mod_dir"
      # 第三处校验：oh-package.json5 的 name
      if [[ "$pkg_name" != "$profile_name" ]] && [[ "$pkg_name" != "@ohos/$profile_name" ]] && [[ "$pkg_name" != "@<unknown>/$profile_name" ]]; then
        err "模块 \"$profile_name\" 命名不一致："
        echo "    build-profile.json5 modules[].name = $profile_name"
        echo "    $mj module.name = $module_name"
        echo "    $pkg_file name = $pkg_name"
        echo "    （建议三处都用 \"$profile_name\" 或 oh-package 用 \"@ohos/$profile_name\"）"
        failed=$((failed + 1))
      else
        ok "模块 \"$profile_name\" · 三处一致"
      fi
      break
    fi
  done

  if [[ -z "$found" ]]; then
    err "build-profile.json5 列了 \"$profile_name\" 但找不到对应的 module.json5（module.name=$profile_name）"
    failed=$((failed + 1))
  fi
done <<<"$profile_modules"

echo
if [[ "$failed" -gt 0 ]]; then
  err "总共 $checked 个模块，$failed 个不一致"
  echo
  echo "修复方法：把以下 3 处的 name 字段统一："
  echo "  1. <root>/build-profile.json5         modules[].name"
  echo "  2. <module>/src/main/module.json5     module.name"
  echo "  3. <module>/oh-package.json5          name  （或 @ohos/<name>）"
  exit 1
fi

ok "$checked 个模块 · 全部三处一致"
exit 0
