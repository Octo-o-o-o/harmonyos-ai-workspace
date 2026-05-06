#!/usr/bin/env bash
# verify-environment.sh
# 检查 HarmonyOS 开发环境是否就位。
# 不修改系统状态，只读检测。

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

ok()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*"; }
sect()  { echo; echo -e "${BLUE}── $* ──${NC}"; }

PASS=0
FAIL=0

check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    ok "$label"
    PASS=$((PASS+1))
  else
    err "$label"
    FAIL=$((FAIL+1))
  fi
}

sect "系统"
echo "  macOS $(sw_vers -productVersion) ($(uname -m))"

sect "命令行工具"
check "git"           git --version
check "node"          node --version
check "brew"          brew --version
check "curl"          curl --version

sect "DevEco Studio"
DEVECO=/Applications/DevEco-Studio.app
if [[ -d "$DEVECO" ]]; then
  ok "DevEco Studio 已安装在 $DEVECO"
  VER=$(defaults read "$DEVECO/Contents/Info" CFBundleShortVersionString 2>/dev/null)
  [[ -n "$VER" ]] && echo "  版本：$VER"
  PASS=$((PASS+1))
else
  err "未发现 DevEco Studio"
  FAIL=$((FAIL+1))
fi

sect "DevEco 工具链 (PATH)"
for cmd in ohpm hvigorw hdc; do
  if command -v $cmd >/dev/null 2>&1; then
    ok "$cmd → $(command -v $cmd)"
    PASS=$((PASS+1))
  else
    warn "$cmd 不在 PATH（请 source ~/.zshrc 或检查 install-deveco-prereqs.sh 是否执行过）"
    FAIL=$((FAIL+1))
  fi
done

sect "SDK"
SDK_LOCATIONS=(
  "$HOME/Library/Huawei/Sdk"
  "$DEVECO/Contents/sdk"
)
SDK_FOUND=0
for loc in "${SDK_LOCATIONS[@]}"; do
  if [[ -d "$loc" ]]; then
    ok "SDK 目录: $loc"
    SDK_FOUND=1
    # 列出版本
    find "$loc" -maxdepth 3 -name "openharmony" -type d 2>/dev/null | head -5 | while read p; do
      echo "    $p"
    done
  fi
done
[[ "$SDK_FOUND" == 1 ]] && PASS=$((PASS+1)) || { warn "未找到任何 HarmonyOS SDK 目录"; FAIL=$((FAIL+1)); }

sect "字体（可选）"
for f in HarmonyOS-Sans HarmonyOSSans HarmonyOS_Sans; do
  if fc-list 2>/dev/null | grep -qi "$f" || ls "/Library/Fonts" "$HOME/Library/Fonts" 2>/dev/null | grep -qi harmony; then
    ok "HarmonyOS Sans 已安装"
    PASS=$((PASS+1))
    break
  fi
done

sect "OpenHarmony 文档（可选，2.7 GB）"
DOC_DIR="$(dirname "$(realpath "$0")")/../upstream-docs/openharmony-docs"
if [[ -d "$DOC_DIR/zh-cn/application-dev" ]]; then
  N=$(find "$DOC_DIR/zh-cn/application-dev" -name "*.md" | wc -l | tr -d ' ')
  ok "本地文档已就绪：$N 个 zh-cn .md 文件"
  PASS=$((PASS+1))
else
  echo "  未拉取（不是必装；按需 bash tools/bootstrap-upstream-docs.sh）"
fi

sect "AI 编码助手"
if command -v claude >/dev/null 2>&1; then
  ok "Claude Code → $(command -v claude)"
  PASS=$((PASS+1))
else
  warn "Claude Code 未装"
  FAIL=$((FAIL+1))
fi
if command -v codex >/dev/null 2>&1; then
  ok "Codex CLI → $(command -v codex)"
  PASS=$((PASS+1))
else
  echo "  Codex CLI 未装（可选）"
fi

sect "总结"
echo
echo -e "  ${GREEN}通过：$PASS${NC}    ${RED}失败：$FAIL${NC}"

if [[ "$FAIL" -gt 0 ]]; then
  echo
  echo "下一步建议（按缺失项给）："

  command -v brew >/dev/null 2>&1 || \
    echo "  · Homebrew 未装：bash tools/install-deveco-prereqs.sh"

  command -v node >/dev/null 2>&1 || \
    echo "  · Node 未装：brew install node 或 跑 install-deveco-prereqs.sh"

  if [[ ! -d /Applications/DevEco-Studio.app ]]; then
    echo "  · DevEco Studio 未装："
    echo "      1) https://developer.huawei.com/consumer/cn/deveco-studio/"
    echo "      2) 登录华为账号 → 下 macOS DMG → 装到 /Applications/"
    echo "      3) 首次启动配 Node/Ohpm/SDK（建议 API 21+22 + 一个 LTS）"
  fi

  for c in hdc ohpm hvigorw; do
    command -v "$c" >/dev/null 2>&1 || \
      echo "  · $c 不在 PATH：跑 bash tools/install-deveco-prereqs.sh 或 source ~/.zshrc"
  done

  command -v claude >/dev/null 2>&1 || \
    echo "  · Claude Code 未装：npm i -g @anthropic-ai/claude-code"

  echo
  echo "  一键串联向导：bash tools/setup-from-scratch.sh"
  exit 1
fi

echo
echo "环境齐备。下一步："
echo "  cd 到鸿蒙 app 项目  →  curl -fsSL .../tools/install.sh | bash  →  claude"
exit 0
