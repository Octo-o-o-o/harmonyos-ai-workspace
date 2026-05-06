#!/usr/bin/env bash
# post-edit.sh — Claude Code PostToolUse 钩子入口
#
# 触发：Edit / Write / MultiEdit 写完文件后由 Claude Code 通过 stdin 传 JSON 调用
# 行为：
#   - .ets / .ts          → ArkTS 反模式扫描（lib/scan-arkts.sh）
#   - oh-package.json5    → OHPM 包名校验（tools/check-ohpm-deps.sh）
#   - module.json5        → 权限最小化提醒（轻量）
#
# 反馈：
#   - 标准错误打印结构化违规
#   - 写入 .claude/.harmonyos-last-scan.txt（AI 下一轮可读）
#   - 退出码 2 → Claude Code 自动把 stderr 注入下一轮 AI 上下文
#
# 不阻断（只提醒）：环境变量 HARMONYOS_HOOK_NONBLOCKING=1 时永远 exit 0

set -u

# 找到本脚本所在目录（避免 cwd 变化时找不到 lib）
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载解析库
# shellcheck source=lib/parse-hook-input.sh
source "$HERE/lib/parse-hook-input.sh"

# 找到项目根的 tools 目录
TOOLS_DIR="$HERE/.."
if [[ ! -d "$TOOLS_DIR" ]]; then
  TOOLS_DIR="$HOOK_PROJECT_DIR/tools"
fi

# 没有可识别文件路径就静默退出（不影响 AI 流程）
if [[ -z "${HOOK_FILE_PATH:-}" || ! -f "$HOOK_FILE_PATH" ]]; then
  exit 0
fi

# 准备结果文件
RESULT_FILE="$HOOK_PROJECT_DIR/.claude/.harmonyos-last-scan.txt"
mkdir -p "$(dirname "$RESULT_FILE")"

# 用临时文件捕获 stderr
TMP_ERR="$(mktemp)"
trap 'rm -f "$TMP_ERR"' EXIT

worst_exit=0

run_check() {
  local script="$1"
  shift
  if [[ -x "$script" || -f "$script" ]]; then
    bash "$script" "$@" 2>>"$TMP_ERR"
    local rc=$?
    if [[ $rc -gt $worst_exit ]]; then
      worst_exit=$rc
    fi
  fi
}

# 按文件类型分发
case "$HOOK_FILE_PATH" in
  *.ets|*.ts)
    run_check "$HERE/lib/scan-arkts.sh" "$HOOK_FILE_PATH"
    ;;
  */oh-package.json5)
    run_check "$TOOLS_DIR/check-ohpm-deps.sh" "$HOOK_FILE_PATH"
    ;;
  */module.json5)
    # 简单提醒：列出已声明的权限，让 AI 自查
    if grep -q '"requestPermissions"' "$HOOK_FILE_PATH" 2>/dev/null; then
      perms=$(grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' "$HOOK_FILE_PATH" | wc -l | tr -d ' ')
      if [[ "$perms" -gt 0 ]]; then
        printf '[PERM-INFO] module.json5 声明了 %s 个权限，请确认是否最小化、已加用户解释\n' "$perms" >>"$TMP_ERR"
      fi
    fi
    ;;
  *)
    exit 0
    ;;
esac

# 把扫描输出固化到结果文件（不论本次是否触发违规）
{
  echo "# HarmonyOS post-edit scan @ $(date '+%Y-%m-%d %H:%M:%S')"
  echo "# file : ${HOOK_FILE_PATH#$HOOK_PROJECT_DIR/}"
  echo "# tool : $HOOK_TOOL_NAME"
  echo
  if [[ -s "$TMP_ERR" ]]; then
    cat "$TMP_ERR"
  else
    echo "[clean] 未发现已知反模式"
  fi
} > "$RESULT_FILE"

# 把违规输出回 stderr（Claude Code 默认把 stderr 注入 AI 上下文）
if [[ -s "$TMP_ERR" ]]; then
  cat "$TMP_ERR" >&2
fi

# 非阻塞模式（CI / 用户自定义）
if [[ "${HARMONYOS_HOOK_NONBLOCKING:-0}" == "1" ]]; then
  exit 0
fi

exit "$worst_exit"
