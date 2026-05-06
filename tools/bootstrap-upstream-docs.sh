#!/usr/bin/env bash
# bootstrap-upstream-docs.sh
# 拉取 OpenHarmony 官方文档镜像到 upstream-docs/openharmony-docs/
# 这份镜像约 2.7 GB，不入主分支（见 .gitignore）。
#
# Usage:
#   bash tools/bootstrap-upstream-docs.sh           # 首次拉取
#   bash tools/bootstrap-upstream-docs.sh --force   # 删除现有再拉
#   bash tools/bootstrap-upstream-docs.sh --update  # 已有 .git 时 git pull
#
# 数据源：
#   主：https://github.com/openharmony-rs/openharmony-docs (镜像)
#   备：https://gitee.com/openharmony/docs.git           (官方原仓)

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
info() { echo -e "${BLUE}[i]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$REPO_ROOT/upstream-docs/openharmony-docs"
PRIMARY_URL="https://github.com/openharmony-rs/openharmony-docs.git"
FALLBACK_URL="https://gitee.com/openharmony/docs.git"

MODE="install"
for arg in "$@"; do
  case "$arg" in
    --force)  MODE="force"  ;;
    --update) MODE="update" ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
  esac
done

mkdir -p "$REPO_ROOT/upstream-docs"
cd "$REPO_ROOT/upstream-docs"

if [[ -d "$TARGET" ]]; then
  case "$MODE" in
    force)
      warn "已存在 $TARGET，--force 模式将删除并重新克隆"
      rm -rf "$TARGET"
      ;;
    update)
      if [[ -d "$TARGET/.git" ]]; then
        info "已存在且含 .git，执行增量 pull"
        cd "$TARGET"
        git pull --depth=1 --ff-only
        ok "更新完成"
        exit 0
      else
        warn "$TARGET 存在但无 .git（可能是手动 clone 后删了 .git）"
        warn "请用 --force 重新拉取，或自行 cd 进去手动处理"
        exit 1
      fi
      ;;
    install)
      ok "已存在 $TARGET，跳过（如需更新加 --update，重拉加 --force）"
      exit 0
      ;;
  esac
fi

info "克隆 OpenHarmony 文档镜像（浅克隆，约 2.7 GB）..."
info "源：$PRIMARY_URL"

if git clone --depth=1 "$PRIMARY_URL" openharmony-docs; then
  ok "克隆完成"
else
  warn "GitHub 镜像失败，尝试 Gitee 官方原仓"
  if git clone --depth=1 "$FALLBACK_URL" openharmony-docs; then
    ok "Gitee 克隆完成"
  else
    err "两个源都失败，请检查网络 / 代理"
    err "也可以手动 clone 到 $TARGET 后再次运行本脚本"
    exit 1
  fi
fi

cd "$TARGET"
ZH_COUNT=$(find zh-cn -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
EN_COUNT=$(find en   -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
SIZE=$(du -sh . 2>/dev/null | awk '{print $1}')

ok "完成：$ZH_COUNT 篇 zh-cn + $EN_COUNT 篇 en，体积 $SIZE"
echo
info "下次更新：bash tools/bootstrap-upstream-docs.sh --update"
info "重新克隆：bash tools/bootstrap-upstream-docs.sh --force"
