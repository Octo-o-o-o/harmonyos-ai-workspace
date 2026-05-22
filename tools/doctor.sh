#!/usr/bin/env bash
# doctor.sh — 检查 HarmonyOS AI Workspace 在当前目录是否真的安装并工作。
#
# 用法（在你的鸿蒙 app 根目录跑）：
#   bash tools/doctor.sh            # 默认输出 PASS/WARN/FAIL
#   bash tools/doctor.sh --quiet    # 只显示问题项
#   bash tools/doctor.sh --json     # 机器可读输出
#
# 退出码：
#   0   全 PASS 或仅 WARN
#   1   有 FAIL（至少一项必须处理）
#   2   不像 HarmonyOS app 项目（一票否决）
#
# 设计原则：
#   1. 只读检测，不修任何文件
#   2. 三态：PASS（绿✓）/ WARN（黄!）/ FAIL（红✗）
#   3. 每个 FAIL 都给"下一步命令"，不只是报错
#   4. 包含 hook 端到端自测（喂一个故意的 STATE-002 看是否被抓住）

set -u

# ─── 颜色 ─────────────────────────────────────────────────────
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" == "" ]]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; DIM='\033[2m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; BLUE=''; DIM=''; NC=''
fi

QUIET="0"
JSON="0"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet) QUIET="1"; shift ;;
    --json)  JSON="1"; QUIET="1"; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) shift ;;
  esac
done

# ─── 状态累积 ─────────────────────────────────────────────────
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
declare -a FAIL_HINTS=()   # FAIL 项的下一步命令
declare -a WARN_HINTS=()
declare -a JSON_ENTRIES=() # for --json

record() {
  # $1=status (PASS|WARN|FAIL)  $2=label  $3=detail  $4=hint(可空)
  local status="$1" label="$2" detail="$3" hint="${4:-}"
  case "$status" in
    PASS)
      PASS_COUNT=$((PASS_COUNT + 1))
      [[ "$QUIET" != "1" ]] && printf "  ${GREEN}[✓]${NC} %s${DIM} — %s${NC}\n" "$label" "$detail"
      ;;
    WARN)
      WARN_COUNT=$((WARN_COUNT + 1))
      printf "  ${YELLOW}[!]${NC} %s ${DIM}— %s${NC}\n" "$label" "$detail"
      [[ -n "$hint" ]] && WARN_HINTS+=("$label → $hint")
      ;;
    FAIL)
      FAIL_COUNT=$((FAIL_COUNT + 1))
      printf "  ${RED}[✗]${NC} %s ${DIM}— %s${NC}\n" "$label" "$detail"
      [[ -n "$hint" ]] && FAIL_HINTS+=("$label → $hint")
      ;;
  esac
  if [[ "$JSON" == "1" ]]; then
    # 简单转义：双引号 + 反斜杠
    local d_esc h_esc
    d_esc="${detail//\\/\\\\}"; d_esc="${d_esc//\"/\\\"}"
    h_esc="${hint//\\/\\\\}";  h_esc="${h_esc//\"/\\\"}"
    JSON_ENTRIES+=("{\"status\":\"$status\",\"label\":\"$label\",\"detail\":\"$d_esc\",\"hint\":\"$h_esc\"}")
  fi
}

section() {
  [[ "$QUIET" == "1" || "$JSON" == "1" ]] && return
  echo
  printf "${BLUE}── %s ──${NC}\n" "$*"
}

# ─── A. 当前目录是 HarmonyOS app 项目吗？──────────────────────
section "项目识别"

IS_HARMONY_APP=0
if [[ -f "AppScope/app.json5" || -f "entry/src/main/module.json5" || -f "build-profile.json5" ]]; then
  IS_HARMONY_APP=1
fi

if [[ "$IS_HARMONY_APP" == "1" ]]; then
  # 提取关键字段
  BUNDLE_NAME="(未知)"
  if [[ -f "AppScope/app.json5" ]]; then
    BUNDLE_NAME=$(grep -E '"bundleName"' AppScope/app.json5 2>/dev/null | head -1 | sed -E 's/.*"bundleName"[^"]*"([^"]+)".*/\1/' || echo "(解析失败)")
  fi
  record PASS "HarmonyOS app 项目" "bundleName=$BUNDLE_NAME"
else
  record FAIL "HarmonyOS app 项目" "当前目录无 AppScope/app.json5 也无 entry/src/main/module.json5" \
    "cd 到你的鸿蒙 app 根目录；或先 bash tools/scaffold-deveco-project.sh 生成脚手架"
fi

# ─── B. 工具链 ────────────────────────────────────────────────
section "DevEco 工具链"

for cmd in hvigorw ohpm hdc; do
  if command -v "$cmd" >/dev/null 2>&1; then
    VER=$("$cmd" --version 2>/dev/null | head -1 || echo "")
    record PASS "$cmd" "$(command -v "$cmd") ${VER:+($VER)}"
  else
    record FAIL "$cmd 不在 PATH" "DevEco SDK 已装但 shell 找不到" \
      "bash tools/install-deveco-prereqs.sh 或 source ~/.zshrc"
  fi
done

if command -v node >/dev/null 2>&1; then
  NODE_V=$(node --version 2>/dev/null)
  record PASS "node" "$NODE_V"
else
  record WARN "node 不在 PATH" "本工具脚本不依赖 node 运行" "可不处理"
fi

# ─── C. 本工具集成 ────────────────────────────────────────────
section "AI 规则文件"

for f in CLAUDE.md AGENTS.md; do
  if [[ -f "$f" ]]; then
    SIZE=$(wc -c < "$f" | tr -d ' ')
    record PASS "$f" "${SIZE} bytes"
  else
    record FAIL "$f 缺失" "AI 助手读不到鸿蒙开发硬约束" \
      "在本目录跑 npx -y harmonyos-ai-workspace 或 curl ... install.sh | bash"
  fi
done

# manifest（用于 uninstall 安全 + 证明是本工具装的）
if [[ -f ".harmonyos-ai-workspace.manifest" ]]; then
  N_WRITTEN=$(grep -c "^written" .harmonyos-ai-workspace.manifest 2>/dev/null || echo 0)
  N_SKIPPED=$(grep -c "^skipped" .harmonyos-ai-workspace.manifest 2>/dev/null || echo 0)
  record PASS "install manifest" "written=$N_WRITTEN, skipped=$N_SKIPPED"
else
  record WARN "install manifest 缺失" "CLAUDE.md/AGENTS.md 可能不是本工具装的（手工拷贝或更早版本）" \
    "保留现状即可；或重新 bash tools/install.sh 让 manifest 生效"
fi

# ─── D. Claude Code 钩子链路 ──────────────────────────────────
section "Claude Code 钩子"

if [[ -f ".claude/settings.json" ]]; then
  record PASS ".claude/settings.json" "存在"

  # 校验钩子命令字符串里指向的脚本存在 + 可执行
  HOOK_SCRIPT="tools/hooks/post-edit.sh"
  if [[ -f "$HOOK_SCRIPT" ]]; then
    if [[ -x "$HOOK_SCRIPT" ]]; then
      record PASS "$HOOK_SCRIPT" "可执行"
    else
      record WARN "$HOOK_SCRIPT" "存在但不可执行" "chmod +x $HOOK_SCRIPT tools/hooks/lib/*.sh"
    fi
  else
    record FAIL "$HOOK_SCRIPT 缺失" "settings.json 引用但文件不在" \
      "重跑 bash tools/install.sh 拉取 hook 文件"
  fi

  # 钩子端到端自测：喂一个故意的 STATE-002，看是否被抓
  # 注意：必须保证 .ets 后缀，scan-arkts.sh 按后缀过滤
  if [[ -x "$HOOK_SCRIPT" ]]; then
    TMP_DIR=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}")
    TMP_ETS="$TMP_DIR/hoaw-doctor-fixture.ets"
    cat > "$TMP_ETS" <<'FIXTURE'
@Entry @Component struct DoctorFixture {
  @State items: number[] = [];
  build() {
    Button('+').onClick(() => { this.items.push(1) })
  }
}
FIXTURE
    HOOK_INPUT="{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$TMP_ETS\"}}"
    HOOK_OUTPUT=$(echo "$HOOK_INPUT" | bash "$HOOK_SCRIPT" 2>&1 || true)
    rm -f "$TMP_ETS"
    rmdir "$TMP_DIR" 2>/dev/null || true

    if echo "$HOOK_OUTPUT" | grep -q "STATE-002"; then
      record PASS "钩子端到端" "故意写 this.items.push() 被 STATE-002 抓到"
    else
      record FAIL "钩子端到端" "fixture .ets 包含 STATE-002 反模式，但钩子没抓到" \
        "bash tools/hooks/lib/scan-arkts.sh \$YOUR_ETS_FILE 看扫描器本身是否工作"
    fi
  fi
else
  record WARN ".claude/settings.json 缺失" "Claude Code 钩子不会触发" \
    "如不用 Claude Code 可忽略；否则 bash tools/install.sh --targets=claude"
fi

# ─── E. AI 工具规则文件 ───────────────────────────────────────
section "其他 AI 工具规则"

# Cursor
if [[ -d ".cursor/rules" ]]; then
  N_MDC=$(find .cursor/rules -name "*.mdc" -type f | wc -l | tr -d ' ')
  if [[ "$N_MDC" -gt 0 ]]; then
    TOTAL_KB=$(du -k .cursor/rules 2>/dev/null | awk '{print $1}')
    record PASS ".cursor/rules/" "${N_MDC} 个 .mdc 文件（合计 ${TOTAL_KB}KB）"
    # 单文件超 12KB 提醒
    for mdc in .cursor/rules/*.mdc; do
      [[ -f "$mdc" ]] || continue
      SIZE_KB=$(du -k "$mdc" | awk '{print $1}')
      if [[ "$SIZE_KB" -gt 12 ]]; then
        record WARN "$(basename "$mdc")" "${SIZE_KB}KB（单文件 > 12KB 可能影响 Cursor 触发精度）" \
          "重跑 bash tools/generate-ai-configs.sh 看是否能分拆"
      fi
    done
  else
    record WARN ".cursor/rules/" "目录存在但无 .mdc 文件"
  fi
else
  record WARN ".cursor/rules/" "未安装（如不用 Cursor 可忽略）" \
    "如要装：bash tools/install.sh --targets=cursor"
fi

# Copilot root
if [[ -f ".github/copilot-instructions.md" ]]; then
  SIZE=$(wc -c < ".github/copilot-instructions.md" | tr -d ' ')
  SIZE_KB=$((SIZE / 1024))
  if [[ "$SIZE" -le 4096 ]]; then
    record PASS ".github/copilot-instructions.md" "${SIZE} bytes（≤4KB，Copilot code-review 安全区）"
  else
    record WARN ".github/copilot-instructions.md" "${SIZE_KB}KB > 4KB（code-review 场景会被截断）" \
      "把详细规则拆到 .github/instructions/*.instructions.md；重跑 bash tools/generate-ai-configs.sh"
  fi
else
  record WARN ".github/copilot-instructions.md" "未安装（如不用 Copilot 可忽略）"
fi

# Copilot 分散规则
if [[ -d ".github/instructions" ]]; then
  N_INSTR=$(find .github/instructions -name "*.instructions.md" -type f | wc -l | tr -d ' ')
  if [[ "$N_INSTR" -gt 0 ]]; then
    record PASS ".github/instructions/" "${N_INSTR} 个 .instructions.md（按 applyTo 触发）"
  fi
fi

# ─── F. MCP ───────────────────────────────────────────────────
section "MCP"

if [[ -f ".mcp.json" ]]; then
  if grep -q '@latest' .mcp.json 2>/dev/null; then
    record WARN ".mcp.json" "依赖了 @latest（mcp-harmonyos 漂移风险）" \
      "改成已验证版本，如 mcp-harmonyos@0.x.y；详见 docs/REVIEW-NEXT-STEPS-2026-05.md § 2.10"
  else
    record PASS ".mcp.json" "存在且未用 @latest"
  fi
else
  record WARN ".mcp.json" "未配置 MCP（可选，对 Claude 设备查询能力有用）"
fi

# ─── G. Skills 目录（如果是 Claude target）──────────────────────
section "Claude Skills"

if [[ -d ".claude/skills" ]]; then
  N_SKILLS=$(find .claude/skills -name "SKILL.md" -type f | wc -l | tr -d ' ')
  if [[ "$N_SKILLS" -ge 1 ]]; then
    record PASS ".claude/skills/" "${N_SKILLS} 个 SKILL.md"
  else
    record WARN ".claude/skills/" "目录存在但无 SKILL.md"
  fi
else
  record WARN ".claude/skills/" "未安装（仅装 codex/cursor target 时不需要）"
fi

# ─── 总结 ─────────────────────────────────────────────────────
if [[ "$JSON" == "1" ]]; then
  # 输出 JSON
  printf '{"pass":%d,"warn":%d,"fail":%d,"items":[' "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT"
  for i in "${!JSON_ENTRIES[@]}"; do
    [[ "$i" -gt 0 ]] && printf ","
    printf "%s" "${JSON_ENTRIES[$i]}"
  done
  printf ']}\n'
else
  echo
  printf "${BLUE}── 总结 ──${NC}\n"
  printf "  ${GREEN}PASS: $PASS_COUNT${NC}    ${YELLOW}WARN: $WARN_COUNT${NC}    ${RED}FAIL: $FAIL_COUNT${NC}\n"

  if [[ "${#FAIL_HINTS[@]}" -gt 0 ]]; then
    echo
    printf "${RED}必须处理：${NC}\n"
    for h in "${FAIL_HINTS[@]}"; do echo "  · $h"; done
  fi
  if [[ "${#WARN_HINTS[@]}" -gt 0 ]]; then
    echo
    printf "${YELLOW}建议处理：${NC}\n"
    for h in "${WARN_HINTS[@]}"; do echo "  · $h"; done
  fi
fi

# 退出码：FAIL=1, 全 PASS/仅 WARN=0；项目不像鸿蒙 app 是一票否决（exit 2）
if [[ "$IS_HARMONY_APP" == "0" ]]; then
  exit 2
fi
[[ "$FAIL_COUNT" -gt 0 ]] && exit 1
exit 0
