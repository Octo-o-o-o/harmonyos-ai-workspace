#!/usr/bin/env bash
# install.sh — 把 HarmonyOS AI Workspace 的规则装到当前鸿蒙 app 项目
#
# 用法：
#   # 在你的鸿蒙 app 根目录下运行：
#   curl -fsSL https://raw.githubusercontent.com/Octo-o-o-o/harmonyos-ai-workspace/main/tools/install.sh | bash
#
#   # 显式指定目标（默认 claude+codex；其他工具需要时显式加）
#   curl -fsSL ... | bash -s -- --targets=claude,codex,cursor
#
#   # 使用国内镜像（GitHub 不通时）
#   curl -fsSL ... | bash -s -- --mirror=ghproxy
#
#   # 卸载
#   curl -fsSL ... | bash -s -- --uninstall
#
# 装到 app 项目里的内容（按 --targets 选择）：
#   CLAUDE.md（含 hook 路径）
#   AGENTS.md
#   .mcp.json
#   .claude/settings.json + .claude/skills/  （--targets 含 claude）
#   .cursor/rules/harmonyos.mdc              （--targets 含 cursor）
#   .github/copilot-instructions.md          （--targets 含 copilot）
#   tools/hooks/                             （所有 target 都装）
#   tools/check-ohpm-deps.sh                 （所有 target 都装）

set -eu

# ─── 配置 ─────────────────────────────────────────────────────
REPO_OWNER="${HOAW_REPO_OWNER:-Octo-o-o-o}"
REPO_NAME="${HOAW_REPO_NAME:-harmonyos-ai-workspace}"
REPO_BRANCH="${HOAW_REPO_BRANCH:-main}"
DEFAULT_TARGETS="claude,codex"

# 颜色
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
err()  { printf "${RED}[✗]${NC} %s\n" "$*"; }
info() { printf "${BLUE}[i]${NC} %s\n" "$*"; }

# ─── 解析参数 ─────────────────────────────────────────────────
TARGETS="$DEFAULT_TARGETS"
MIRROR=""
ACTION="install"
FORCE="0"
INSTALL_DIR="$PWD"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --targets=*) TARGETS="${1#*=}"; shift ;;
    --mirror=*) MIRROR="${1#*=}"; shift ;;
    --uninstall) ACTION="uninstall"; shift ;;
    --force) FORCE="1"; shift ;;
    --dir=*) INSTALL_DIR="${1#*=}"; shift ;;
    -h|--help)
      sed -n '2,28p' "$0" 2>/dev/null || head -28 "$0"
      exit 0
      ;;
    *) err "未知参数：$1"; exit 64 ;;
  esac
done

# 把逗号分隔的 targets 拆成数组
IFS=',' read -ra TARGET_LIST <<<"$TARGETS"

# ─── 来源 URL（支持镜像） ─────────────────────────────────────
case "$MIRROR" in
  ghproxy) BASE_URL="https://ghproxy.net/https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$REPO_BRANCH" ;;
  fastgit) BASE_URL="https://raw.fastgit.org/$REPO_OWNER/$REPO_NAME/$REPO_BRANCH" ;;
  "")      BASE_URL="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$REPO_BRANCH" ;;
  *)       BASE_URL="$MIRROR" ;;
esac

# ─── 子函数 ───────────────────────────────────────────────────
fetch() {
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -f "$dest" && "$FORCE" != "1" ]]; then
    warn "$dest 已存在，跳过（加 --force 覆盖）"
    return 0
  fi
  if curl -fsSL --max-time 30 "$url" -o "$dest"; then
    ok "$dest"
  else
    err "下载失败：$url"
    return 1
  fi
}

contains_target() {
  local needle="$1"
  for t in "${TARGET_LIST[@]}"; do
    [[ "$t" == "$needle" ]] && return 0
  done
  return 1
}

# ─── 卸载 ─────────────────────────────────────────────────────
uninstall() {
  cd "$INSTALL_DIR"
  info "卸载 HarmonyOS AI Workspace from $INSTALL_DIR"
  for f in CLAUDE.md AGENTS.md .mcp.json .cursor/rules/harmonyos.mdc .github/copilot-instructions.md; do
    if [[ -f "$f" ]]; then
      rm -f "$f"
      ok "removed $f"
    fi
  done
  for d in .claude/skills .claude/.harmonyos-last-scan.txt tools/hooks; do
    if [[ -e "$d" ]]; then
      rm -rf "$d"
      ok "removed $d"
    fi
  done
  if [[ -f .claude/settings.json ]]; then
    if grep -q "tools/hooks/post-edit.sh" .claude/settings.json 2>/dev/null; then
      rm -f .claude/settings.json
      ok "removed .claude/settings.json (本仓库注入的)"
    else
      warn "保留 .claude/settings.json（可能含你自己的配置）"
    fi
  fi
  # 清空目录（如果空）
  for d in .cursor/rules .cursor .github tools .claude; do
    [[ -d "$d" ]] && rmdir "$d" 2>/dev/null || true
  done
  ok "卸载完成"
}

# ─── 安装 ─────────────────────────────────────────────────────
install() {
  cd "$INSTALL_DIR"

  info "安装 HarmonyOS AI Workspace v0.1 → $INSTALL_DIR"
  info "目标：${TARGETS}"
  info "源：${BASE_URL}"
  echo

  # 1) 顶层规则文件（所有 target 共享）
  fetch "$BASE_URL/CLAUDE.md"  "CLAUDE.md"
  fetch "$BASE_URL/AGENTS.md"  "AGENTS.md"
  fetch "$BASE_URL/.mcp.json"  ".mcp.json"

  # 2) 钩子工具链（所有 target 都装；非 Claude 用户也能 git pre-commit 调用）
  fetch "$BASE_URL/tools/hooks/post-edit.sh"           "tools/hooks/post-edit.sh"
  fetch "$BASE_URL/tools/hooks/lib/parse-hook-input.sh" "tools/hooks/lib/parse-hook-input.sh"
  fetch "$BASE_URL/tools/hooks/lib/scan-arkts.sh"      "tools/hooks/lib/scan-arkts.sh"
  fetch "$BASE_URL/tools/check-ohpm-deps.sh"           "tools/check-ohpm-deps.sh"
  chmod +x tools/hooks/post-edit.sh tools/hooks/lib/*.sh tools/check-ohpm-deps.sh

  # 3) Claude Code 专属：settings.json + skills/
  if contains_target "claude"; then
    fetch "$BASE_URL/.claude/settings.json"                                 ".claude/settings.json"
    fetch "$BASE_URL/.claude/skills/manifest.json"                          ".claude/skills/manifest.json"
    fetch "$BASE_URL/.claude/skills/README.md"                              ".claude/skills/README.md"
    for skill in arkts-rules state-management build-debug signing-publish harmonyos-review; do
      fetch "$BASE_URL/.claude/skills/$skill/SKILL.md"                      ".claude/skills/$skill/SKILL.md"
    done
    fetch "$BASE_URL/.claude/skills/harmonyos-review/references/checklist.md"        ".claude/skills/harmonyos-review/references/checklist.md"
    fetch "$BASE_URL/.claude/skills/harmonyos-review/references/report-template.md"  ".claude/skills/harmonyos-review/references/report-template.md"
    fetch "$BASE_URL/.claude/skills/harmonyos-review/references/official-docs.md"    ".claude/skills/harmonyos-review/references/official-docs.md"
  fi

  # 4) Cursor 专属
  if contains_target "cursor"; then
    fetch "$BASE_URL/.cursor/rules/harmonyos.mdc" ".cursor/rules/harmonyos.mdc" || \
      warn "Cursor 配置生成器尚未在远端可用；本地用 tools/generate-ai-configs.sh 生成"
  fi

  # 5) Copilot 专属
  if contains_target "copilot"; then
    fetch "$BASE_URL/.github/copilot-instructions.md" ".github/copilot-instructions.md" || \
      warn "Copilot 配置尚未在远端可用；本地用 tools/generate-ai-configs.sh 生成"
  fi

  echo
  ok "安装完成！"
  echo
  info "立即自测（30 秒确认装对了）："
  echo
  echo "  # 1. 跑一遍钩子，看到 [STATE-002 · High] 输出 = 钩子工作"
  echo "  cat > /tmp/_test.ets <<'EOF'"
  echo "  @Entry @Component struct X {"
  echo "    @State items: number[] = [];"
  echo "    build() { Button('+').onClick(() => { this.items.push(1) }) }"
  echo "  }"
  echo "  EOF"
  echo "  echo '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"/tmp/_test.ets\"}}' | bash tools/hooks/post-edit.sh"
  echo "  rm /tmp/_test.ets"
  echo
  info "下一步："
  echo "  · Claude Code:  claude       （CLAUDE.md 自动加载，钩子已就绪）"
  echo "  · Codex CLI:    codex        （AGENTS.md 自动加载）"
  echo "  · 卸载：        curl -fsSL $BASE_URL/tools/install.sh | bash -s -- --uninstall"
  echo
  info "故障排查 / 完整文档： https://github.com/$REPO_OWNER/$REPO_NAME#常见故障排查"
  echo
  if ! command -v claude >/dev/null 2>&1 && ! command -v codex >/dev/null 2>&1; then
    warn "未检测到 Claude Code 或 Codex CLI——本仓库的规则需要它们才生效"
    echo "  · Claude Code: npm i -g @anthropic-ai/claude-code"
    echo "  · Codex CLI:   brew install codex（或 npm i -g @openai/codex）"
    echo "  · 完整新手向导: $BASE_URL/docs/SETUP-FROM-SCRATCH.md"
  fi
  if [[ ! -d /Applications/DevEco-Studio.app && "$OSTYPE" == "darwin"* ]]; then
    warn "未检测到 DevEco Studio——hvigorw / hdc / 模拟器都需要它"
    echo "  · 下载: https://developer.huawei.com/consumer/cn/deveco-studio/"
    echo "  · 完整向导: $BASE_URL/docs/SETUP-FROM-SCRATCH.md"
  fi
}

# ─── 入口 ─────────────────────────────────────────────────────
case "$ACTION" in
  install)   install ;;
  uninstall) uninstall ;;
  *) err "未知 action: $ACTION"; exit 64 ;;
esac
