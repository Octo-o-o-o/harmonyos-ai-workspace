#!/usr/bin/env bash
# install-deveco-prereqs.sh
# 在 macOS（Apple Silicon 或 Intel）上为 HarmonyOS 开发准备前置依赖。
# 不会自动下载 DevEco Studio（需要登录华为账号），但会引导你完成全部步骤。
#
# 使用：
#   bash tools/install-deveco-prereqs.sh
#
# 这个脚本是幂等的：可以反复运行，已就绪的项目会被跳过。

set -e
set -o pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[i]${NC} $*"; }
ok()      { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
err()     { echo -e "${RED}[✗]${NC} $*"; }
section() { echo; echo -e "${BLUE}=== $* ===${NC}"; }

# -----------------------------------------------------------------------------
# 0. 探测系统
# -----------------------------------------------------------------------------
section "0. 系统探测"

if [[ "$OSTYPE" != "darwin"* ]]; then
  err "本脚本仅支持 macOS。检测到 OSTYPE=$OSTYPE"
  exit 1
fi

ARCH="$(uname -m)"
MACOS_VER="$(sw_vers -productVersion)"
info "macOS $MACOS_VER ($ARCH)"

if [[ "$ARCH" == "arm64" ]]; then
  ok "Apple Silicon 检测成功，将下载 ARM 版 DevEco Studio。"
else
  warn "Intel Mac 检测到，将使用 x86_64 版 DevEco Studio（仍受支持，但 ARM 性能更好）。"
fi

# -----------------------------------------------------------------------------
# 1. Homebrew
# -----------------------------------------------------------------------------
section "1. Homebrew"

if command -v brew >/dev/null 2>&1; then
  ok "Homebrew 已安装：$(brew --version | head -1)"
else
  warn "未检测到 Homebrew。即将安装……"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ "$ARCH" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

# -----------------------------------------------------------------------------
# 2. Git
# -----------------------------------------------------------------------------
section "2. Git"

if command -v git >/dev/null 2>&1; then
  ok "Git 已安装：$(git --version)"
else
  info "安装 Git..."
  brew install git
fi

# -----------------------------------------------------------------------------
# 3. Node.js（系统层，与 DevEco 内置版本互不影响）
# -----------------------------------------------------------------------------
section "3. Node.js"

if command -v node >/dev/null 2>&1; then
  NODE_VER="$(node --version)"
  ok "Node 已安装：$NODE_VER"
  MAJOR="$(echo "$NODE_VER" | sed 's/v//' | cut -d. -f1)"
  if [[ "$MAJOR" -lt 18 ]]; then
    warn "Node 版本 ($NODE_VER) 偏低，建议 18 LTS 或 22 LTS。"
  fi
else
  info "安装 Node 22 LTS..."
  brew install node@22
  brew link --overwrite --force node@22 || true
fi

# -----------------------------------------------------------------------------
# 4. HarmonyOS Sans 字体（设计与预览用）
# -----------------------------------------------------------------------------
section "4. HarmonyOS Sans 字体（可选）"

read -p "是否安装 HarmonyOS Sans 系列字体？(y/N) " yn
case $yn in
  [Yy]*)
    brew install --cask font-harmonyos-sans || true
    brew install --cask font-harmonyos-sans-sc || true
    brew install --cask font-harmonyos-sans-tc || true
    brew install --cask font-harmonyos-sans-naskh-arabic || true
    ok "字体安装完成。"
    ;;
  *)
    info "跳过字体安装。"
    ;;
esac

# -----------------------------------------------------------------------------
# 5. 检查 DevEco Studio
# -----------------------------------------------------------------------------
section "5. DevEco Studio"

DEVECO_PATH="/Applications/DevEco-Studio.app"

if [[ -d "$DEVECO_PATH" ]]; then
  VER="$(defaults read "$DEVECO_PATH/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo unknown)"
  ok "DevEco Studio 已安装：$VER"
  ok "App 路径：$DEVECO_PATH"
else
  warn "DevEco Studio 尚未安装。"
  echo
  echo "  ⓘ 由于华为下载链接需要登录账号，无法自动下载。请按以下步骤手动安装："
  echo
  echo "  1. 浏览器打开：https://developer.huawei.com/consumer/cn/deveco-studio/"
  echo "  2. 登录华为账号（没有的话先到 https://id.huawei.com 注册）"
  echo "  3. 下载 macOS ${ARCH/x86_64/Intel} 版本的 .dmg 文件（约 1.2-1.6 GB）"
  echo "  4. 双击 .dmg，把 DevEco-Studio 拖到 /Applications"
  echo "  5. 首次启动，按向导让 IDE 自动下载 SDK / Node / OHPM"
  echo
  read -p "完成安装后回车继续，跳过则按 Ctrl+C... " _
fi

# -----------------------------------------------------------------------------
# 6. 配置 PATH
# -----------------------------------------------------------------------------
section "6. PATH 配置"

ZSHRC="$HOME/.zshrc"
MARK="# >>> HarmonyOS DevEco Studio toolchain >>>"
END_MARK="# <<< HarmonyOS DevEco Studio toolchain <<<"

if grep -qF "$MARK" "$ZSHRC" 2>/dev/null; then
  ok "PATH 配置块已存在于 $ZSHRC，跳过。"
else
  info "向 $ZSHRC 追加 DevEco 工具链 PATH 配置..."
  cat >> "$ZSHRC" <<'EOF'

# >>> HarmonyOS DevEco Studio toolchain >>>
export DEVECO_HOME="/Applications/DevEco-Studio.app/Contents"
if [[ -d "$DEVECO_HOME" ]]; then
  [[ -d "$DEVECO_HOME/tools/ohpm/bin" ]] && export PATH="$DEVECO_HOME/tools/ohpm/bin:$PATH"
  [[ -d "$DEVECO_HOME/tools/hvigor/bin" ]] && export PATH="$DEVECO_HOME/tools/hvigor/bin:$PATH"
  [[ -d "$DEVECO_HOME/tools/node/bin" ]] && export DEVECO_NODE="$DEVECO_HOME/tools/node/bin"
fi

# hdc 路径：DevEco 6.x 的内置 SDK 是固定路径，优先使用
if [[ -x "$DEVECO_HOME/sdk/default/openharmony/toolchains/hdc" ]]; then
  export PATH="$DEVECO_HOME/sdk/default/openharmony/toolchains:$PATH"
fi

# 备用：用户级 SDK（旧版布局）。用 ls 替代 shell glob 以兼容 zsh nomatch
if ! command -v hdc >/dev/null 2>&1; then
  HDC_FALLBACK=$(ls -d "$HOME/Library/Huawei/Sdk"/*/openharmony/toolchains 2>/dev/null | head -1)
  [[ -n "$HDC_FALLBACK" && -x "$HDC_FALLBACK/hdc" ]] && export PATH="$HDC_FALLBACK:$PATH"
  unset HDC_FALLBACK
fi
# <<< HarmonyOS DevEco Studio toolchain <<<
EOF
  ok "已写入。请运行：source ~/.zshrc"
fi

# -----------------------------------------------------------------------------
# 7. OHPM 加速（如果工具已就位）
# -----------------------------------------------------------------------------
section "7. OHPM 镜像配置"

OHPM_BIN="$DEVECO_PATH/Contents/tools/ohpm/bin/ohpm"
if [[ -x "$OHPM_BIN" ]]; then
  CURRENT_REG="$("$OHPM_BIN" config get registry 2>/dev/null | tail -1 || echo unknown)"
  info "当前 OHPM registry: $CURRENT_REG"
  read -p "是否切到中国大陆镜像 https://ohpm.openharmony.cn/ohpm/ ？(y/N) " yn
  case $yn in
    [Yy]*)
      "$OHPM_BIN" config set registry https://ohpm.openharmony.cn/ohpm/
      ok "已切换镜像。"
      ;;
    *)
      info "保持原镜像。"
      ;;
  esac
else
  warn "未找到 ohpm 二进制（$OHPM_BIN）。请先在 IDE 中完成首次启动配置。"
fi

# -----------------------------------------------------------------------------
# 8. 验证
# -----------------------------------------------------------------------------
section "8. 验证"

source "$ZSHRC" 2>/dev/null || true

echo "node    : $(node --version 2>&1)"
echo "git     : $(git --version 2>&1)"
echo "brew    : $(brew --version 2>&1 | head -1)"
echo
[[ -d "$DEVECO_PATH" ]] && ok "DevEco Studio 已就位" || warn "DevEco Studio 未安装，请按 §5 步骤手动下载"
echo
ok "前置依赖检查完成。"
echo
info "下一步："
echo "  1) source ~/.zshrc"
echo "  2) 启动 DevEco Studio：open -a 'DevEco-Studio'"
echo "  3) 跟着首次启动向导下载 SDK"
echo "  4) 阅读：00-getting-started/03-first-project.md"
