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

sect "OpenHarmony 文档"
DOC_DIR="$(dirname "$(realpath "$0")")/../upstream-docs/openharmony-docs"
if [[ -d "$DOC_DIR/zh-cn/application-dev" ]]; then
  N=$(find "$DOC_DIR/zh-cn/application-dev" -name "*.md" | wc -l | tr -d ' ')
  ok "本地文档已就绪：$N 个 zh-cn .md 文件"
  PASS=$((PASS+1))
else
  err "本地文档缺失：$DOC_DIR"
  FAIL=$((FAIL+1))
fi

sect "总结"
echo
echo -e "  ${GREEN}通过：$PASS${NC}    ${RED}失败：$FAIL${NC}"
echo
if [[ "$FAIL" -gt 0 ]]; then
  echo "建议：运行 tools/install-deveco-prereqs.sh，并完成 DevEco Studio 的首次启动向导。"
  exit 1
fi
exit 0
