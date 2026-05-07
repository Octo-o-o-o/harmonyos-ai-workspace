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
#   # 干跑（不写文件、只列清单）
#   curl -fsSL ... | bash -s -- --dry-run
#
#   # 强制覆盖已存在文件
#   curl -fsSL ... | bash -s -- --force
#
#   # 卸载（仅删 install 时本工具实际写入的、未被本地改过的文件）
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
#
# 安全设计（v0.4 起）：
#   1. 每次 install 写 .harmonyos-ai-workspace.manifest，记录所有写入文件 + sha256
#   2. 默认不覆盖已存在文件（避免吃掉用户原配置），但会在 manifest 标记 skipped
#   3. uninstall 只删 manifest 标记为 written 的文件
#   4. uninstall 校验 checksum，本地改过的文件保留（除非 --force）

set -eu

# ─── 配置 ─────────────────────────────────────────────────────
REPO_OWNER="${HOAW_REPO_OWNER:-Octo-o-o-o}"
REPO_NAME="${HOAW_REPO_NAME:-harmonyos-ai-workspace}"
REPO_BRANCH="${HOAW_REPO_BRANCH:-main}"
DEFAULT_TARGETS="claude,codex"
MANIFEST_FILE=".harmonyos-ai-workspace.manifest"

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
DRY_RUN="0"
INSTALL_DIR="$PWD"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --targets=*) TARGETS="${1#*=}"; shift ;;
    --mirror=*)  MIRROR="${1#*=}"; shift ;;
    --uninstall) ACTION="uninstall"; shift ;;
    --force)     FORCE="1"; shift ;;
    --dry-run)   DRY_RUN="1"; shift ;;
    --dir=*)     INSTALL_DIR="${1#*=}"; shift ;;
    -h|--help)
      sed -n '2,40p' "$0" 2>/dev/null || head -40 "$0"
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

# ─── 通用工具 ─────────────────────────────────────────────────
sha256() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" 2>/dev/null | awk '{print $1}'
  else echo "no-checksum"
  fi
}

# manifest 行格式：<status>\t<path>\t<sha256_or_reason>
manifest_init() {
  {
    echo "# HarmonyOS AI Workspace install manifest"
    echo "# Format: <status>\\t<path>\\t<sha256_or_reason>"
    echo "# DO NOT EDIT — used by 'install.sh --uninstall' to know what to remove"
    echo "# status:  written  = 本工具实际写入"
    echo "#          skipped  = 已存在被跳过（uninstall 不动）"
    echo "#          failed   = 下载失败"
    echo "# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# Source: $BASE_URL"
    echo "# Targets: $TARGETS"
  } > "$MANIFEST_FILE"
}

manifest_record() {
  local status="$1" path="$2" extra="$3"
  printf '%s\t%s\t%s\n' "$status" "$path" "$extra" >> "$MANIFEST_FILE"
}

# 累积报告用
WRITTEN_FILES=()
SKIPPED_FILES=()
FAILED_FILES=()

fetch() {
  local url="$1" dest="$2"

  if [[ "$DRY_RUN" == "1" ]]; then
    if [[ -f "$dest" ]]; then
      printf "  [dry] skip (exists): %s\n" "$dest"
    else
      printf "  [dry] write: %s\n" "$dest"
    fi
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  if [[ -f "$dest" && "$FORCE" != "1" ]]; then
    warn "$dest 已存在，跳过（你的原配置受到保护；如要被本工具接管请加 --force）"
    manifest_record "skipped" "$dest" "pre-existing"
    SKIPPED_FILES+=("$dest")
    return 0
  fi
  if curl -fsSL --max-time 30 "$url" -o "$dest"; then
    ok "$dest"
    manifest_record "written" "$dest" "$(sha256 "$dest")"
    WRITTEN_FILES+=("$dest")
  else
    err "下载失败：$url"
    manifest_record "failed" "$dest" "fetch-error"
    FAILED_FILES+=("$dest")
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

  if [[ ! -f "$MANIFEST_FILE" ]]; then
    err "找不到 $MANIFEST_FILE —— 此目录看起来不是用本工具装的，或 manifest 已被删除。"
    err "为安全起见拒绝卸载：避免误删用户原有 CLAUDE.md / AGENTS.md 等。"
    err "如确实需要清理，手动删除你确定是本工具引入的文件即可。"
    exit 1
  fi

  info "卸载 HarmonyOS AI Workspace from $INSTALL_DIR"
  info "依据：${MANIFEST_FILE}（仅删本工具实际写入且未被本地修改的文件）"
  echo

  local removed=0 modified=0 missing=0 skipped_kept=0

  while IFS=$'\t' read -r status path checksum; do
    [[ -z "$status" || "${status:0:1}" == "#" ]] && continue
    case "$status" in
      written)
        if [[ ! -f "$path" ]]; then
          missing=$((missing + 1))
          continue
        fi
        # checksum 校验：用户改过则保留（除非 --force）
        local current
        current=$(sha256 "$path")
        if [[ "$current" != "$checksum" && "$checksum" != "no-checksum" && "$FORCE" != "1" ]]; then
          warn "$path 已被本地修改（checksum 不匹配），保留；--force 可强制删"
          modified=$((modified + 1))
          continue
        fi
        if [[ "$DRY_RUN" == "1" ]]; then
          printf "  [dry] would remove: %s\n" "$path"
        else
          rm -f "$path"
          ok "removed $path"
        fi
        removed=$((removed + 1))
        ;;
      skipped)
        skipped_kept=$((skipped_kept + 1))   # install 时跳过的，本来就是用户原文件，绝不动
        ;;
    esac
  done < "$MANIFEST_FILE"

  # 把空目录递归清理掉
  if [[ "$DRY_RUN" != "1" ]]; then
    # 先删运行时产物（钩子写入的，manifest 不跟踪）
    rm -f .claude/.harmonyos-last-scan.txt 2>/dev/null || true
    # 用 find 递归删空目录（比一一列稳，处理任意嵌套深度）
    for root in .claude .cursor .github tools; do
      [[ -d "$root" ]] && find "$root" -depth -type d -empty -delete 2>/dev/null || true
    done
    rm -f "${MANIFEST_FILE}"
  fi

  echo
  info "卸载报告："
  echo "  · 已删除（本工具写入且未被改过）：$removed"
  echo "  · 保留（你已修改过）：           $modified"
  echo "  · 保留（install 时已存在跳过的）：$skipped_kept"
  echo "  · 跳过（manifest 列出但已不存在）：$missing"
  ok "卸载完成"
}

# ─── 安装 ─────────────────────────────────────────────────────
install() {
  cd "$INSTALL_DIR"

  info "安装 HarmonyOS AI Workspace → $INSTALL_DIR"
  info "目标：${TARGETS}"
  info "源：${BASE_URL}"
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] 不会真写文件，仅列出动作清单"
  elif [[ "$FORCE" == "1" ]]; then
    warn "[--force] 已存在文件将被覆盖（你的原配置不受保护）"
  fi
  echo

  if [[ "$DRY_RUN" != "1" ]]; then
    manifest_init
  fi

  # 1) 顶层规则文件（所有 target 共享）
  fetch "$BASE_URL/CLAUDE.md"  "CLAUDE.md"
  fetch "$BASE_URL/AGENTS.md"  "AGENTS.md"
  fetch "$BASE_URL/.mcp.json"  ".mcp.json"

  # 2) 钩子工具链（所有 target 都装；非 Claude 用户也能 git pre-commit 调用）
  fetch "$BASE_URL/tools/hooks/post-edit.sh"            "tools/hooks/post-edit.sh"
  fetch "$BASE_URL/tools/hooks/lib/parse-hook-input.sh" "tools/hooks/lib/parse-hook-input.sh"
  fetch "$BASE_URL/tools/hooks/lib/scan-arkts.sh"       "tools/hooks/lib/scan-arkts.sh"
  fetch "$BASE_URL/tools/check-ohpm-deps.sh"            "tools/check-ohpm-deps.sh"
  if [[ "$DRY_RUN" != "1" ]]; then
    chmod +x tools/hooks/post-edit.sh tools/hooks/lib/*.sh tools/check-ohpm-deps.sh 2>/dev/null || true
  fi

  # 2b) OHPM 黑/白名单数据（脚本会自动加载这些外部文件 → 不拉就退化为内联兜底）
  fetch "$BASE_URL/tools/data/ohpm-blacklist.txt" "tools/data/ohpm-blacklist.txt" || \
    warn "ohpm-blacklist.txt 拉取失败；脚本会回退到内联 11 项核心黑名单"
  fetch "$BASE_URL/tools/data/ohpm-whitelist.txt" "tools/data/ohpm-whitelist.txt" || \
    warn "ohpm-whitelist.txt 拉取失败；脚本会回退到内联白名单"

  # 3) Claude Code 专属：settings.json + skills/
  if contains_target "claude"; then
    fetch "$BASE_URL/.claude/settings.json"                                 ".claude/settings.json"
    fetch "$BASE_URL/.claude/skills/manifest.json"                          ".claude/skills/manifest.json"
    fetch "$BASE_URL/.claude/skills/README.md"                              ".claude/skills/README.md"
    for skill in arkts-rules state-management build-debug signing-publish harmonyos-review runtime-pitfalls multimodal-llm web-bridge; do
      fetch "$BASE_URL/.claude/skills/$skill/SKILL.md"                      ".claude/skills/$skill/SKILL.md" || true
    done
    fetch "$BASE_URL/.claude/skills/harmonyos-review/references/checklist.md"        ".claude/skills/harmonyos-review/references/checklist.md" || true
    fetch "$BASE_URL/.claude/skills/harmonyos-review/references/report-template.md"  ".claude/skills/harmonyos-review/references/report-template.md" || true
    fetch "$BASE_URL/.claude/skills/harmonyos-review/references/official-docs.md"    ".claude/skills/harmonyos-review/references/official-docs.md" || true
    fetch "$BASE_URL/.claude/skills/arkts-rules/references/spec-quick-ref.md"        ".claude/skills/arkts-rules/references/spec-quick-ref.md" || true
    fetch "$BASE_URL/.claude/skills/build-debug/references/develop-debug-build.md"   ".claude/skills/build-debug/references/develop-debug-build.md" || true
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
  info "安装报告："
  echo "  · 已写入：             ${#WRITTEN_FILES[@]} 个文件"
  echo "  · 已跳过（你的原文件）：${#SKIPPED_FILES[@]} 个文件"
  echo "  · 失败：               ${#FAILED_FILES[@]} 个文件"
  echo
  if [[ ${#SKIPPED_FILES[@]} -gt 0 ]]; then
    warn "以下文件已存在被跳过——本工具规则**未生效**于这些文件："
    for f in "${SKIPPED_FILES[@]}"; do echo "    · $f"; done
    echo
    info "如果你想用本工具的版本接管这些文件："
    echo "    · 备份原文件后重跑：bash tools/install.sh --force"
    echo "    · 或手动 diff 合并：远端版在 $BASE_URL/<path>"
    echo
  fi
  if [[ ${#FAILED_FILES[@]} -gt 0 ]]; then
    err "以下文件下载失败（可能镜像不通；试 --mirror=ghproxy）："
    for f in "${FAILED_FILES[@]}"; do echo "    · $f"; done
    echo
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] 完成。要真安装请去掉 --dry-run。"
    return 0
  fi

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
  echo "  · 卸载：        bash tools/install.sh --uninstall  （安全：只删本工具写入的）"
  echo
  info "故障排查 / 完整文档： https://github.com/${REPO_OWNER}/${REPO_NAME}#常见故障排查"
  echo
  if ! command -v claude >/dev/null 2>&1 && ! command -v codex >/dev/null 2>&1; then
    warn "未检测到 Claude Code 或 Codex CLI——本仓库的规则需要它们才生效"
    echo "  · Claude Code: npm i -g @anthropic-ai/claude-code"
    echo "  · Codex CLI:   brew install codex（或 npm i -g @openai/codex）"
    echo "  · 完整新手向导: $BASE_URL/docs/SETUP-FROM-SCRATCH.md"
  fi
  if [[ ! -d /Applications/DevEco-Studio.app && "${OSTYPE:-}" == "darwin"* ]]; then
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
