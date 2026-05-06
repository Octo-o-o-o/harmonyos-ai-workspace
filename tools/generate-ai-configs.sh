#!/usr/bin/env bash
# generate-ai-configs.sh — 从 .claude/skills/ + AGENTS.md 拼接出其他 AI 工具的配置
#
# 真正的单源 fan-out：脚本里**不**手写规则，全部从已有 SKILL.md 读取。
# 这样改 SKILL.md 就够了，不用记着同步两份。
#
# v0.2 支持的目标：
#   cursor   →  .cursor/rules/harmonyos.mdc        （含 frontmatter + globs）
#   copilot  →  .github/copilot-instructions.md    （纯 markdown）
#
# 用法：
#   bash tools/generate-ai-configs.sh                       # 默认全部
#   bash tools/generate-ai-configs.sh --targets=cursor      # 指定目标
#   bash tools/generate-ai-configs.sh --check               # 只校验源文件齐全
#
# 退出码：0 成功 / 2 源缺失或目标写入失败

set -eu

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
info() { printf "${BLUE}[i]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
err()  { printf "${RED}[✗]${NC} %s\n" "$*"; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

TARGETS="cursor,copilot"
CHECK_ONLY="0"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --targets=*) TARGETS="${1#*=}"; shift ;;
    --check)     CHECK_ONLY="1"; shift ;;
    -h|--help)   sed -n '2,17p' "$0"; exit 0 ;;
    *) shift ;;
  esac
done

# ─── 源文件清单（写完整路径，校验存在） ─────────────────────────
SKILL_ARKTS=".claude/skills/arkts-rules/SKILL.md"
SKILL_STATE=".claude/skills/state-management/SKILL.md"
SKILL_BUILD=".claude/skills/build-debug/SKILL.md"
SKILL_SIGN=".claude/skills/signing-publish/SKILL.md"
AGENTS_MD="AGENTS.md"

REQUIRED_SOURCES=("$SKILL_ARKTS" "$SKILL_STATE" "$SKILL_BUILD" "$SKILL_SIGN" "$AGENTS_MD")

# 校验源都存在
missing=0
for f in "${REQUIRED_SOURCES[@]}"; do
  if [[ ! -f "$f" ]]; then
    err "源文件缺失: $f"
    missing=$((missing + 1))
  fi
done
if [[ "$missing" -gt 0 ]]; then
  err "请先确保所有源 SKILL.md 与 AGENTS.md 都存在"
  exit 2
fi
[[ "$CHECK_ONLY" == "1" ]] && { ok "所有源齐全"; exit 0; }

# ─── 工具：剥掉 markdown frontmatter（首尾 ---）──────────────────
strip_frontmatter() {
  local f="$1"
  awk '
    BEGIN { fm = 0 }
    /^---$/ {
      if (NR == 1 || fm == 1) { fm++; next }
    }
    fm < 2 && NR == 1 && !/^---$/ { print; next }
    fm >= 2 || NR > 1 { if (fm < 2 && NR > 1) next; print }
  ' "$f"
}

# ─── 拼接合规则正文（4 个 SKILL 的"必读"段 + 关键导航） ──────────
build_body() {
  cat <<'EOF'
> 平台：HarmonyOS 6 系列（API 21 / 22 现行稳定线，6.1 dev beta），ArkTS + ArkUI 声明式。
> 训练数据缺失提醒：你（AI）默认会写出 TypeScript 风格但 ArkTS 编译器拒绝的代码。**先读完本文再写代码**。

EOF

  echo "## 一、ArkTS 严格语法（来源：.claude/skills/arkts-rules/SKILL.md）"
  echo
  strip_frontmatter "$SKILL_ARKTS"
  echo

  echo "## 二、ArkUI 状态管理（来源：.claude/skills/state-management/SKILL.md）"
  echo
  strip_frontmatter "$SKILL_STATE"
  echo

  echo "## 三、构建与调试（来源：.claude/skills/build-debug/SKILL.md，按需展开）"
  echo
  echo "改完代码必跑："
  echo
  echo '```bash'
  echo "ohpm install"
  echo "hvigorw codeLinter                               # 或 bash tools/run-linter.sh"
  echo "hvigorw assembleHap -p buildMode=debug"
  echo '```'
  echo
  echo "完整 hdc / 错误码 / 三种产物速查见上面提到的 SKILL.md。"
  echo

  echo "## 四、签名与上架（来源：.claude/skills/signing-publish/SKILL.md，按需展开）"
  echo
  echo "签名三件套：\`.p12\` 私钥、\`.cer\` 证书、\`.p7b\` Profile。**调试与发布两套绝不混用**。"
  echo "中国市场提审 Top 20 拒因：见 \`07-publishing/checklist-2026-rejection-top20.md\`。"
  echo

  echo "## 五、AGENTS.md 跨工具简版（来源：AGENTS.md）"
  echo
  strip_frontmatter "$AGENTS_MD"
}

# ─── 生成 cursor ─────────────────────────────────────────────
generate_cursor() {
  local out=".cursor/rules/harmonyos.mdc"
  mkdir -p "$(dirname "$out")"
  info "生成 $out · 从 ${#REQUIRED_SOURCES[@]} 个源拼接"

  {
    cat <<'HEAD'
---
description: HarmonyOS / ArkTS / ArkUI 开发规则。在编辑 .ets / .ts / module.json5 / oh-package.json5 时自动激活。
globs:
  - "**/*.ets"
  - "**/*.ts"
  - "**/module.json5"
  - "**/oh-package.json5"
  - "**/AppScope/app.json5"
alwaysApply: false
---

# HarmonyOS / ArkTS / ArkUI 开发硬约束

HEAD
    build_body
    cat <<'TAIL'

---
> 此文件由 `tools/generate-ai-configs.sh` 从 `.claude/skills/*/SKILL.md` 自动生成。**请勿手动编辑**——改源文件后重跑脚本。
TAIL
  } > "$out"
  ok "$out"
}

# ─── 生成 copilot ────────────────────────────────────────────
generate_copilot() {
  local out=".github/copilot-instructions.md"
  mkdir -p "$(dirname "$out")"
  info "生成 $out · 从 ${#REQUIRED_SOURCES[@]} 个源拼接"

  {
    echo "# HarmonyOS / ArkTS / ArkUI 开发规则（GitHub Copilot 版）"
    echo
    build_body
    cat <<'TAIL'

---
> 此文件由 `tools/generate-ai-configs.sh` 从 `.claude/skills/*/SKILL.md` 自动生成。**请勿手动编辑**——改源文件后重跑脚本。
TAIL
  } > "$out"
  ok "$out"
}

# ─── 入口 ────────────────────────────────────────────────────
IFS=',' read -ra TARGET_LIST <<<"$TARGETS"
for t in "${TARGET_LIST[@]}"; do
  case "$t" in
    cursor)  generate_cursor ;;
    copilot) generate_copilot ;;
    *) warn "目标 \"$t\" 暂未支持（v0.2 仅 cursor / copilot）" ;;
  esac
done

echo
ok "完成。源 → 目标："
echo "  · ${#REQUIRED_SOURCES[@]} 个源文件 SKILL.md + AGENTS.md"
[[ -f .cursor/rules/harmonyos.mdc ]]      && echo "  → .cursor/rules/harmonyos.mdc"
[[ -f .github/copilot-instructions.md ]]  && echo "  → .github/copilot-instructions.md"
