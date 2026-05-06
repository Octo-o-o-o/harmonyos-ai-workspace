#!/usr/bin/env bash
# setup-from-scratch.sh — 从零到 Hello HarmonyOS · 半自动向导
#
# 它解决的问题：
#   新手装鸿蒙开发环境会卡 6 个断点（DevEco 下载 / SDK / PATH /
#   Claude Code / 创建 app / 装本仓库规则）。本脚本把能自动的全自动，
#   做不到的（华为账号下载等）给清晰指引。
#
# 用法：
#   bash tools/setup-from-scratch.sh                          # 交互式向导
#   bash tools/setup-from-scratch.sh --app-dir=PATH           # 指定 app 路径，避免询问
#   bash tools/setup-from-scratch.sh --skip-prereqs           # 已装基础工具时跳过
#   bash tools/setup-from-scratch.sh --no-claude-code         # 不装 Claude Code（手动装或用 Codex）
#
# 完整流程：
#   1. 调 install-deveco-prereqs.sh：装 Homebrew / git / node + 配 PATH
#   2. 检查 DevEco：未装则打开下载页 + 给 5 分钟教程
#   3. 装 Claude Code（npm i -g @anthropic-ai/claude-code）
#   4. 询问 / 接收 app 项目路径（你已有的鸿蒙工程，或新建）
#   5. 在 app 目录调 install.sh 装本仓库规则
#   6. 在 app 目录跑钩子自测（fixture）
#   7. 输出 cheat sheet：cd app && claude

set -u

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()      { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
warn()    { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
err()     { printf "${RED}[✗]${NC} %s\n" "$*"; }
info()    { printf "${BLUE}[i]${NC} %s\n" "$*"; }
hint()    { printf "${CYAN}    %s${NC}\n" "$*"; }
section() { echo; printf "${BLUE}=== %s ===${NC}\n" "$*"; }
ask()     { printf "${YELLOW}[?]${NC} %s " "$*"; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR=""
SKIP_PREREQS="0"
NO_CLAUDE_CODE="0"
ASSUME_YES="0"

for arg in "$@"; do
  case "$arg" in
    --app-dir=*)     APP_DIR="${arg#*=}" ;;
    --skip-prereqs)  SKIP_PREREQS="1" ;;
    --no-claude-code) NO_CLAUDE_CODE="1" ;;
    -y|--yes)        ASSUME_YES="1" ;;
    -h|--help)       sed -n '2,20p' "$0"; exit 0 ;;
  esac
done

# ─── 系统约束 ────────────────────────────────────────────────
if [[ "$OSTYPE" != "darwin"* ]]; then
  err "本脚本目前仅支持 macOS。Windows 用户请用 WSL2 或参见 docs/SETUP-FROM-SCRATCH.md"
  exit 1
fi

# ─── Banner ─────────────────────────────────────────────────
clear 2>/dev/null || true
cat <<'EOF'
┌─────────────────────────────────────────────────────────────┐
│  HarmonyOS AI Workspace · 从零到 Hello HarmonyOS 向导       │
│  能自动的全自动；做不到的（华为账号登录等）给清晰指引       │
└─────────────────────────────────────────────────────────────┘
EOF
echo

# ─── Step 1: 基础工具 ────────────────────────────────────────
section "Step 1/6 · 基础工具（Homebrew / git / node / 字体 / PATH）"

if [[ "$SKIP_PREREQS" == "1" ]]; then
  info "已加 --skip-prereqs，跳过此步"
else
  if [[ -x "$REPO_ROOT/tools/install-deveco-prereqs.sh" ]]; then
    info "调用 install-deveco-prereqs.sh"
    bash "$REPO_ROOT/tools/install-deveco-prereqs.sh" || {
      err "install-deveco-prereqs.sh 失败。修复后重跑本脚本。"
      exit 1
    }
  else
    warn "install-deveco-prereqs.sh 未找到，跳过基础工具检查"
  fi
fi

# ─── Step 2: DevEco Studio ──────────────────────────────────
section "Step 2/6 · DevEco Studio"

DEVECO=/Applications/DevEco-Studio.app
if [[ -d "$DEVECO" ]]; then
  VER=$(defaults read "$DEVECO/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo unknown)
  ok "DevEco Studio 已安装：$VER"
else
  warn "DevEco Studio 未安装"
  echo
  hint "DevEco 必须从华为开发者站下载（需登录华为账号，脚本无法自动）："
  hint "  1) 打开 https://developer.huawei.com/consumer/cn/deveco-studio/"
  hint "  2) 登录华为账号（没有先注册：https://id.huawei.com）"
  hint "  3) 选 macOS (ARM) 或 (X86)，下载 ~1.6 GB DMG"
  hint "  4) 双击 DMG → 拖 DevEco-Studio 到 Applications"
  hint "  5) 首次启动会被 Gatekeeper 拦截："
  hint "     系统设置 → 隐私与安全 → 允许 DevEco-Studio 运行"
  hint "  6) 完成首次向导（Node 选 Install / SDK 选 API 21+22 + LTS / Ohpm Install）"
  echo
  if [[ "$ASSUME_YES" == "1" ]]; then
    info "已加 -y，自动打开下载页"
    open "https://developer.huawei.com/consumer/cn/deveco-studio/" 2>/dev/null || true
  else
    ask "是否打开下载页？[y/N]"
    read -r open_ans
    if [[ "$open_ans" =~ ^[Yy] ]]; then
      open "https://developer.huawei.com/consumer/cn/deveco-studio/" 2>/dev/null || true
      info "下载页已打开。安装完成后，重跑本脚本（DevEco 已装则会跳过此步）"
    fi
  fi
  echo
  ask "DevEco 现在装好了吗？[y/N/skip]"
  read -r de_ans
  if [[ "$de_ans" =~ ^[Yy] ]]; then
    if [[ -d "$DEVECO" ]]; then
      ok "确认 DevEco Studio 已安装"
    else
      err "$DEVECO 不存在；请先装好再重跑本脚本"
      exit 1
    fi
  elif [[ "$de_ans" =~ ^[Ss] ]]; then
    warn "跳过 DevEco 检查（不推荐——hvigorw / hdc / SDK 都依赖它）"
  else
    info "OK，下次装好再来。详见 docs/SETUP-FROM-SCRATCH.md"
    exit 0
  fi
fi

# ─── Step 3: PATH 工具链 ─────────────────────────────────────
section "Step 3/6 · PATH 工具链（hdc / ohpm / hvigorw）"

# install-deveco-prereqs.sh 已经做过 PATH，但有时 DevEco 后装的话需要补
PATH_OK="1"
for cmd in hdc ohpm; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd → $(command -v "$cmd")"
  else
    warn "$cmd 不在当前 shell 的 PATH"
    PATH_OK="0"
  fi
done

if [[ "$PATH_OK" != "1" ]]; then
  hint "重启终端 / 跑 source ~/.zshrc 后再试；如仍不通："
  hint "  bash tools/install-deveco-prereqs.sh   # 会重新写 PATH 到 ~/.zshrc"
fi

# ─── Step 4: AI 编码助手 ─────────────────────────────────────
section "Step 4/6 · AI 编码助手"

if [[ "$NO_CLAUDE_CODE" == "1" ]]; then
  info "已加 --no-claude-code，跳过 Claude Code 安装"
else
  if command -v claude >/dev/null 2>&1; then
    ok "Claude Code 已安装：$(claude --version 2>/dev/null || echo 'version unknown')"
  else
    warn "Claude Code 未安装"
    if [[ "$ASSUME_YES" == "1" ]]; then
      install_claude="y"
    else
      ask "是否现在装 Claude Code（npm i -g @anthropic-ai/claude-code）？[Y/n]"
      read -r install_claude
    fi
    if [[ ! "$install_claude" =~ ^[Nn] ]]; then
      if command -v npm >/dev/null 2>&1; then
        info "运行 npm i -g @anthropic-ai/claude-code"
        npm i -g @anthropic-ai/claude-code || {
          err "Claude Code 安装失败。手动装：npm i -g @anthropic-ai/claude-code"
        }
      else
        err "npm 不在 PATH。先装 Node.js（重跑 install-deveco-prereqs.sh）"
      fi
    fi
  fi
fi

# Codex CLI 是可选的
if command -v codex >/dev/null 2>&1; then
  ok "Codex CLI 也已装：$(codex --version 2>/dev/null || echo 'version unknown')"
else
  hint "想用 Codex CLI？brew install codex 或 npm i -g @openai/codex（可选）"
fi

# ─── Step 5: 选 / 创建 app 项目 ──────────────────────────────
section "Step 5/6 · 鸿蒙 app 项目（装规则的目标）"

if [[ -z "$APP_DIR" ]]; then
  echo
  hint "本仓库的规则要装到一个**鸿蒙 app 项目**目录（不是本仓库本身）"
  hint "如果你还没建过鸿蒙 app："
  hint "  1) 打开 DevEco Studio"
  hint "  2) File → New → Create Project → Empty Ability"
  hint "  3) Save location 选 ~/WorkSpace/apps/my-first-app/"
  hint "  4) Stage 模型 + ArkTS"
  hint "  5) 点 Finish 等 Hvigor sync 完"
  echo
  if [[ "$ASSUME_YES" == "1" ]]; then
    info "已加 -y 但未指定 --app-dir；跳过此步"
  else
    ask "你的鸿蒙 app 项目根目录路径（绝对路径，留空跳过此步）："
    read -r APP_DIR
  fi
fi

if [[ -n "$APP_DIR" ]]; then
  # 展开 ~ 与相对路径
  APP_DIR="${APP_DIR/#\~/$HOME}"
  APP_DIR="$(cd "$APP_DIR" 2>/dev/null && pwd || echo "$APP_DIR")"

  if [[ ! -d "$APP_DIR" ]]; then
    err "目录不存在：$APP_DIR"
    info "用 DevEco 创建一个 app 后，重跑：bash tools/setup-from-scratch.sh --app-dir=$APP_DIR"
    exit 1
  fi

  # 简单检测是否像鸿蒙工程（有 hvigorfile.ts 或 oh-package.json5）
  if [[ ! -f "$APP_DIR/hvigorfile.ts" && ! -f "$APP_DIR/oh-package.json5" ]]; then
    warn "$APP_DIR 看起来不像鸿蒙工程（缺 hvigorfile.ts / oh-package.json5）"
    ask "确认仍在此目录装规则？[y/N]"
    read -r confirm
    [[ ! "$confirm" =~ ^[Yy] ]] && { info "取消"; exit 0; }
  fi

  ok "目标 app: $APP_DIR"

  # ─── Step 6: 装本仓库规则 + 自测 ────────────────────────────
  section "Step 6/6 · 装本仓库规则 + 自测"

  info "在 $APP_DIR 下调用 install.sh"
  cd "$APP_DIR"
  if bash "$REPO_ROOT/tools/install.sh"; then
    ok "规则已装到 $APP_DIR"
  else
    err "install.sh 失败"
    exit 1
  fi

  echo
  info "跑钩子自测（模拟 Claude Code 写一个含反模式的 .ets）"
  TEST_FILE="$APP_DIR/.harmonyos-setup-test.ets"
  cat > "$TEST_FILE" <<'EOF'
@Entry @Component struct X {
  @State items: number[] = [];
  build() { Button('+').onClick(() => { this.items.push(1) }) }
}
EOF
  payload='{"tool_name":"Edit","tool_input":{"file_path":"'"$TEST_FILE"'"}}'
  if echo "$payload" | bash "$APP_DIR/tools/hooks/post-edit.sh" 2>&1 | grep -q "STATE-002"; then
    ok "钩子工作正常 · 命中 STATE-002（数组就地 mutation）"
  else
    warn "钩子未命中 STATE-002——请检查 .claude/settings.json"
  fi
  rm -f "$TEST_FILE"

  cd "$REPO_ROOT"
fi

# ─── 完成总结 ───────────────────────────────────────────────
echo
cat <<EOF
${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${GREEN}  从零到 Hello HarmonyOS · 完成${NC}
${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${CYAN}下一步：${NC}
EOF

if [[ -n "$APP_DIR" ]]; then
  cat <<EOF
  cd "$APP_DIR"
  claude       # 启动 Claude Code，开始写鸿蒙代码
EOF
else
  cat <<EOF
  1. 用 DevEco Studio 创建 app 项目（File → New → Empty Ability）
  2. cd 到 app 项目根目录
  3. curl -fsSL https://raw.githubusercontent.com/Octo-o-o-o/harmonyos-ai-workspace/main/tools/install.sh | bash
  4. claude       # 启动 Claude Code
EOF
fi

cat <<EOF

${CYAN}校验环境：${NC} bash $REPO_ROOT/tools/verify-environment.sh
${CYAN}遇到问题：${NC} $REPO_ROOT/docs/SETUP-FROM-SCRATCH.md
${CYAN}文档：${NC}     https://github.com/Octo-o-o-o/harmonyos-ai-workspace
EOF
