#!/usr/bin/env bash
# check-ohpm-deps.sh — 校验 oh-package.json5 中的依赖是否真实存在
#
# 痛点（来自 ArkEval / Phodal AutoDev / CSDN 多个帖子）：
#   AI 写代码时常虚构 OHPM 包名，编译时才发现不存在。
#
# 校验策略（按可靠性降序）：
#   1) 黑名单：已知由 AI 虚构 / 常被混淆的包名 → 直接报错
#   2) 白名单：已知真实存在的核心包 → 标 ✓
#   3) OHPM registry openapi（curl）：实测比 ohpm CLI 的 registry 端点稳定
#      · 返回包详情 JSON → 存在；返回 {"code":200,"body":"success"} → 查无此包
#   3.5) ohpm CLI fallback：ohpm 6.x 用 `info`，旧版用 `view`（自动探测）
#   4) 都不行：标 ? 让 AI 主动去 https://ohpm.openharmony.cn/ 确认
#
# Usage:
#   bash check-ohpm-deps.sh path/to/oh-package.json5
#   bash check-ohpm-deps.sh                  # 默认查找当前目录所有 oh-package.json5
#
# 退出码：
#   0 - 全部通过（黑名单未命中）
#   2 - 黑名单命中（AI 虚构 / 弃用 / 已知错误）

set -u

# ─── 黑名单：已知由 AI 虚构或常被混淆的包名 ─────────────────────
# 格式：每行 "<fake-name>|<reason>"
# 可在外部文件 tools/data/ohpm-blacklist.txt 扩展
#
# ⚠️ 维护纪律（2026-07 教训）：黑名单只收录**核验过的当前事实**。
#   TPC（OpenHarmony 三方库中心）持续在移植 npm 知名库——"不存在"是时变事实，
#   每次 release 前用 registry openapi / `ohpm info` 逐条重核。
#   本清单曾把真实存在的 @ohos/axios（TPC 官方移植，20 万+ 下载）误判为虚构包。
BLACKLIST_INLINE=$(cat <<'EOF'
@ohos/lottie-player|不存在；真实包名是 @ohos/lottie（不带 -player）
@ohos/lodash|不存在；OHPM 有白名单化纯 JS 包 lodash（无前缀），或用 ArrayList / HashMap（@kit.ArkTS）
@ohos/moment|不存在；用 @kit.LocalizationKit 的 i18n.DateTimeFormat 或白名单包 dayjs
@ohos/dayjs|不存在；OHPM 直接用 dayjs（无前缀，白名单化纯 JS 包）或 @kit.LocalizationKit
@ohos/react|不存在；鸿蒙是 ArkUI 声明式，不是 React
@ohos/vue|不存在；鸿蒙是 ArkUI 声明式
@ohos/express|不存在；鸿蒙不在 Node 生态
@ohos/jsonwebtoken|不存在；用 @kit.AuthenticationKit 或自实现（TPC 有 ohos_jsonwebtoken 项目，包名需在 registry 核验后再用）
@ohos/uuid|不存在；用 @kit.AbilityKit 或自实现
@ohos/socket.io-client|不存在；真实包名是 @ohos/socketio（TPC 移植版），或用 @kit.NetworkKit 的 webSocket
EOF
)

# ─── 白名单：已知真实存在的核心 / 常用包 ───────────────────────
# 来源：DevEco 默认模板、OHPM 热门下载、华为官方文档、registry openapi 核验（2026-07-09）
WHITELIST_INLINE=$(cat <<'EOF'
@ohos/hypium
@ohos/hamock
@ohos/hvigor
@ohos/hvigor-ohos-plugin
@ohos/lottie
@ohos/router
@ohos/svg-mapping
@ohos/agconnect-core
@ohos/agconnect-auth
@ohos/agconnect-cloud
@ohos/agconnect-storage
@ohos/agconnect-database
@ohos/agconnect-feedback
@ohos/agconnect-applinking
@ohos/aki
@ohos/crash
@ohos/hammertest
@ohos/imageknife
@ohos/mcimagecompress
@ohos/sm-crypto
@ohos/turbomodule
@ohos/axios
@ohos/socketio
@ohos/crypto-js
dayjs
lodash
EOF
)

# ─── 加载外部扩展（可选） ──────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/data/ohpm-blacklist.txt" ]] && BLACKLIST_INLINE+=$'\n'"$(cat "$SCRIPT_DIR/data/ohpm-blacklist.txt")"
[[ -f "$SCRIPT_DIR/data/ohpm-whitelist.txt" ]] && WHITELIST_INLINE+=$'\n'"$(cat "$SCRIPT_DIR/data/ohpm-whitelist.txt")"

# ─── 解析输入文件 ──────────────────────────────────────────────
TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  TARGET="$(find . -maxdepth 4 -name 'oh-package.json5' | head -1 || true)"
fi
if [[ -z "$TARGET" || ! -f "$TARGET" ]]; then
  # 安静退出（钩子场景下文件不存在不要骚扰用户）
  exit 0
fi

# 计算相对路径
REL="$TARGET"
if [[ -n "${HOOK_PROJECT_DIR:-}" && "$TARGET" == "$HOOK_PROJECT_DIR"/* ]]; then
  REL="${TARGET#$HOOK_PROJECT_DIR/}"
fi

# 提取 dependencies 和 devDependencies 中的包名
# json5 比 json 容忍（注释、单引号），但我们这里只做最简单的字符串提取
extract_deps() {
  # 匹配形如 "包名": "版本" 或 '包名': '版本'
  # 仅在 dependencies / devDependencies / dynamicDependencies 块内
  awk '
    /"(dependencies|devDependencies|dynamicDependencies)"[[:space:]]*:[[:space:]]*\{/ { in_dep=1; next }
    in_dep && /^\s*\}/ { in_dep=0; next }
    in_dep {
      if (match($0, /["\047][^"\047]+["\047][[:space:]]*:[[:space:]]*["\047][^"\047]+["\047]/)) {
        s = substr($0, RSTART, RLENGTH)
        # 拆出 key
        gsub(/["\047]/, "", s)
        split(s, parts, ":")
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", parts[1])
        if (length(parts[1]) > 0) print parts[1]
      }
    }
  ' "$1"
}

deps="$(extract_deps "$TARGET")"
if [[ -z "$deps" ]]; then
  exit 0
fi

# ─── 校验 ────────────────────────────────────────────────────
fake_count=0
unknown_count=0
ok_count=0

# ohpm 6.x 把 `view` 子命令改名为 `info`（2026 实测 6.1.2 已无 view）。
# 懒探测：只有真正需要 CLI fallback 时才跑 --help（ohpm 启动 ~1.5s，
# 钩子高频路径全命中黑白名单时不该白付这个成本）。
OHPM_CLI=""
command -v ohpm >/dev/null 2>&1 && OHPM_CLI="ohpm"
OHPM_SUBCMD=""
OHPM_SUBCMD_PROBED="0"

probe_ohpm_subcmd() {
  [[ "$OHPM_SUBCMD_PROBED" == "1" ]] && return 0
  OHPM_SUBCMD_PROBED="1"
  [[ -z "$OHPM_CLI" ]] && return 0
  if "$OHPM_CLI" info --help >/dev/null 2>&1; then
    OHPM_SUBCMD="info"
  elif "$OHPM_CLI" view --help >/dev/null 2>&1; then
    OHPM_SUBCMD="view"
  fi
}

CURL_BIN=""
command -v curl >/dev/null 2>&1 && CURL_BIN="curl"

# URL-encode 包名里的 / 和 @（openapi 路径参数要求）
urlencode_pkg() {
  local s="$1"
  s="${s//\//%2F}"
  printf '%s' "$s"
}

while IFS= read -r pkg; do
  [[ -z "$pkg" ]] && continue

  # 1) 黑名单
  reason="$(echo "$BLACKLIST_INLINE" | awk -F'|' -v p="$pkg" '$1==p{print $2; exit}')"
  if [[ -n "$reason" ]]; then
    printf '[OHPM-FAKE · High] %s: 包名 "%s" %s\n' "$REL" "$pkg" "$reason" >&2
    fake_count=$((fake_count + 1))
    continue
  fi

  # 2) 白名单
  if echo "$WHITELIST_INLINE" | grep -qFx "$pkg"; then
    ok_count=$((ok_count + 1))
    continue
  fi

  # 3) OHPM registry openapi（curl）——实测比 ohpm CLI 的 registry 端点稳定。
  #    存在 → 返回包详情 JSON（含 "name"）；不存在 → {"code":200,"body":"success"}。
  #    非公开接口可能变动：任何意外形态都按网络类降级，不阻断。
  if [[ -n "$CURL_BIN" ]]; then
    API_OUT=$("$CURL_BIN" -s --max-time 15 \
      "https://ohpm.openharmony.cn/ohpmweb/registry/oh-package/openapi/v1/detail/$(urlencode_pkg "$pkg")" 2>/dev/null) || API_OUT=""
    if [[ -n "$API_OUT" ]]; then
      if printf '%s' "$API_OUT" | grep -q '"body":"success"'; then
        printf '[OHPM-FAKE · High] %s: 包名 "%s" 在 OHPM registry 上明确不存在（openapi 查无此包）\n' "$REL" "$pkg" >&2
        fake_count=$((fake_count + 1))
        continue
      fi
      if printf '%s' "$API_OUT" | grep -q '"name"[[:space:]]*:'; then
        ok_count=$((ok_count + 1))
        continue
      fi
      # 意外响应形态（接口变动 / 网关错误页）→ 落到 CLI fallback / UNKNOWN
    fi
  fi

  # 3.5) ohpm CLI fallback（DevEco 装好就有）
  # v0.4 起分类失败原因，避免 registry 502 / 网络问题被误判为 OHPM-FAKE High。
  # 注意顺序：先 network 后 not-found——ohpm 在 registry 502 时也会误报
  # "NOTFOUND ... from all the registries"（2026-07 实测），必须先按网络错分类。
  probe_ohpm_subcmd
  if [[ -n "$OHPM_CLI" && -n "$OHPM_SUBCMD" ]]; then
    OHPM_RC=0
    OHPM_OUT=$(timeout 15 "$OHPM_CLI" "$OHPM_SUBCMD" "$pkg" 2>&1) || OHPM_RC=$?
    if [[ "$OHPM_RC" == "0" ]]; then
      ok_count=$((ok_count + 1))
      continue
    fi
    # timeout 自身的退出码 124 → 网络问题
    if [[ "$OHPM_RC" == "124" ]] || echo "$OHPM_OUT" | grep -qiE "etimedout|econnrefused|enetunreach|getaddrinfo|connect.*failed|network|timeout|502|503|504|bad gateway|reset by peer|tls handshake|connection refused"; then
      printf '[OHPM-NET · Low] %s: 包名 "%s" 因网络/registry 问题无法核验（ohpm %s 网络错误，rc=%s）；不阻断，建议网通后重跑\n' "$REL" "$pkg" "$OHPM_SUBCMD" "$OHPM_RC" >&2
      unknown_count=$((unknown_count + 1))
      continue
    fi
    if echo "$OHPM_OUT" | grep -qiE "not found|notfound|404|does not exist|no such package|package.*not.*exist"; then
      printf '[OHPM-FAKE · High] %s: 包名 "%s" 在 OHPM registry 上明确不存在（ohpm %s 报 not-found）\n' "$REL" "$pkg" "$OHPM_SUBCMD" >&2
      fake_count=$((fake_count + 1))
      continue
    fi
    # 其他失败（鉴权 / 配置 / ohpm 自身错）→ 保守降级为 UNKNOWN，不当假包
    printf '[OHPM-UNKNOWN · Medium] %s: 包名 "%s" ohpm %s 返回 rc=%s 但既非 not-found 也非网络错；请手动在 https://ohpm.openharmony.cn/ 核验\n' "$REL" "$pkg" "$OHPM_SUBCMD" "$OHPM_RC" >&2
    unknown_count=$((unknown_count + 1))
    continue
  fi

  # 4) 都没法判定 → 让 AI 主动确认
  printf '[OHPM-UNKNOWN · Medium] %s: 包名 "%s" 无法离线核验，请人/AI 在 https://ohpm.openharmony.cn/ 搜索确认\n' "$REL" "$pkg" >&2
  unknown_count=$((unknown_count + 1))
done <<<"$deps"

# ─── 总结 ────────────────────────────────────────────────────
total=$((ok_count + unknown_count + fake_count))
if [[ "$fake_count" -gt 0 ]]; then
  printf '\n[summary] %s · %d 包：✓ %d / ? %d / FAKE %d\n' \
    "$REL" "$total" "$ok_count" "$unknown_count" "$fake_count" >&2
  exit 2
fi

if [[ "$unknown_count" -gt 0 ]]; then
  printf '\n[summary] %s · %d 包：✓ %d / ? %d（请确认未知项）\n' \
    "$REL" "$total" "$ok_count" "$unknown_count" >&2
fi

exit 0
