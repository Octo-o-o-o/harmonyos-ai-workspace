#!/usr/bin/env bash
# run-linter.sh — 在不打开 DevEco Studio 的前提下跑 ArkTS codeLinter
#
# 何时用：
#   · CI / GitHub Actions
#   · git pre-commit hook
#   · AI 助手在终端 /bash 中显式跑深度校验（hook scan-arkts 是浅扫，这里是真编译期 lint）
#
# 用法：
#   bash tools/run-linter.sh                         # 当前项目
#   bash tools/run-linter.sh --quick                 # 仅本次 git diff 改动的 .ets/.ts
#   bash tools/run-linter.sh --strict                # 把 warning 当 error（CI 用）
#
# 退出码：
#   0  - clean
#   1  - 有 warning
#   2  - 有 error 或 hvigorw 调用失败

set -u

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
err()  { printf "${RED}[✗]${NC} %s\n" "$*"; }
info() { printf "${BLUE}[i]${NC} %s\n" "$*"; }

QUICK="0"
STRICT="0"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick)  QUICK="1"; shift ;;
    --strict) STRICT="1"; shift ;;
    -h|--help)
      sed -n '2,16p' "$0"; exit 0 ;;
    *) err "未知参数：$1"; exit 64 ;;
  esac
done

# ─── 找 hvigorw ─────────────────────────────────────────────
HVIGORW=""
if [[ -x "./hvigorw" ]]; then
  HVIGORW="./hvigorw"
elif command -v hvigorw >/dev/null 2>&1; then
  HVIGORW="$(command -v hvigorw)"
else
  # 尝试 DevEco 默认安装位置（macOS）
  for sdk in ~/Library/Huawei/Sdk/HarmonyOS-NEXT-DB1/openharmony \
             ~/Library/Huawei/Sdk/openharmony \
             /Applications/DevEco-Studio.app/Contents/sdk/HarmonyOS-NEXT-DB1/openharmony; do
    for v in "$sdk"/*/toolchains/hvigor; do
      [[ -x "$v" ]] && HVIGORW="$v" && break 2
    done
  done
fi

if [[ -z "$HVIGORW" ]]; then
  err "找不到 hvigorw。请在鸿蒙工程根目录运行（应有 hvigorw 文件），或装好 DevEco Studio。"
  exit 2
fi
ok "hvigorw: $HVIGORW"

# ─── 跑 codeLinter ──────────────────────────────────────────
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

if [[ "$QUICK" == "1" ]] && command -v git >/dev/null 2>&1; then
  CHANGED=$(git diff --name-only --diff-filter=ACM HEAD 2>/dev/null | grep -E '\.(ets|ts)$' || true)
  if [[ -z "$CHANGED" ]]; then
    info "本次没改 .ets/.ts，跳过"
    exit 0
  fi
  info "增量扫描："
  echo "$CHANGED" | sed 's/^/  · /'
fi

info "跑 hvigorw codeLinter..."
if ! "$HVIGORW" codeLinter --no-daemon 2>&1 | tee "$LOG"; then
  err "hvigorw 退出非零"
  exit 2
fi

# ─── 解析结果 ───────────────────────────────────────────────
errors="$(grep -cE '^\[ERROR\]|error:' "$LOG" 2>/dev/null || echo 0)"
warnings="$(grep -cE '^\[WARN(ING)?\]|warning:' "$LOG" 2>/dev/null || echo 0)"
errors="${errors//$'\n'/}"
warnings="${warnings//$'\n'/}"

echo
info "summary · errors: ${errors:-0} · warnings: ${warnings:-0}"

if [[ "${errors:-0}" -gt 0 ]]; then
  exit 2
fi
if [[ "${warnings:-0}" -gt 0 ]]; then
  if [[ "$STRICT" == "1" ]]; then
    err "STRICT 模式下 warning 视为失败"
    exit 2
  fi
  exit 1
fi

ok "clean"
exit 0
