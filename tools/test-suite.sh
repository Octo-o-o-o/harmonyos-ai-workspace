#!/usr/bin/env bash
# test-suite.sh — 真回归测试套件
#
# 由 `npm test` 调用。比 v0.2/v0.3 的 `bash xxx || true` 强：
#   - 9 个 .ets fixture 检查 exit code 与预期匹配
#   - 4 个 sample template 必须全部 clean（exit 0）
#   - JSON 模式产出合法 JSON
#   - --stats 模式输出含规则计数
#   - check-ohpm-deps 在 fake fixture 上必须 exit=2
#   - install.sh --dry-run 在 tempdir 上不写文件
#   - generate-ai-configs.sh --check 通过
#
# 退出码：0 全过；1 任意 assertion 失败

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass=0; fail=0
assert_pass() { printf "${GREEN}✓${NC} %s\n" "$*"; pass=$((pass + 1)); }
assert_fail() { printf "${RED}✗${NC} %s\n" "$*"; fail=$((fail + 1)); }

echo "═══ HarmonyOS AI Workspace · regression test suite ═══"
echo

# ─── 1) fixture exit code 断言 ────────────────────────────
echo "[1/6] fixture exit code"
declare -A EXPECTED=(
  [BadState]=2 [BadArkTS]=2 [BadDecorators]=2 [BadSecurityKit]=2
  [BadRuntimePitfalls]=2 [InlineDecorators]=2 [CustomDialogState]=2 [ReusableState]=2
  [GoodPrefStore]=0
)
for f in "${!EXPECTED[@]}"; do
  bash tools/hooks/lib/scan-arkts.sh "tools/hooks/test-fixtures/${f}.ets" >/dev/null 2>&1
  rc=$?
  expect="${EXPECTED[$f]}"
  if [[ "$rc" == "$expect" ]]; then
    assert_pass "fixture $f → exit=$rc"
  else
    assert_fail "fixture $f → exit=$rc (expected $expect)"
  fi
done

# ─── 2) sample templates 必须全 clean ─────────────────────
echo
echo "[2/6] sample templates"
for f in $(find samples/templates -name '*.ets' -o -name '*.ts' 2>/dev/null); do
  bash tools/hooks/lib/scan-arkts.sh "$f" >/dev/null 2>&1
  rc=$?
  if [[ "$rc" == "0" ]]; then
    assert_pass "template $f → clean"
  else
    assert_fail "template $f → exit=$rc (expected 0)"
  fi
done

# ─── 3) JSON 模式产出合法 JSON 含具体规则 ID ─────────────
echo
echo "[3/6] --json mode"
JSON=$(bash tools/hooks/lib/scan-arkts.sh --json tools/hooks/test-fixtures/BadArkTS.ets 2>/dev/null)
if echo "$JSON" | python3 -m json.tool >/dev/null 2>&1; then
  assert_pass "BadArkTS.ets --json valid JSON"
else
  assert_fail "BadArkTS.ets --json INVALID JSON"
fi
if echo "$JSON" | python3 -c 'import sys, json; data=json.load(sys.stdin); rules={r["rule"] for r in data}; sys.exit(0 if "ARKTS-001" in rules else 1)'; then
  assert_pass "JSON 含期望规则 ARKTS-001"
else
  assert_fail "JSON 缺 ARKTS-001"
fi

# ─── 4) --stats 模式 ─────────────────────────────────────
echo
echo "[4/6] --stats mode"
STATS=$(bash tools/hooks/lib/scan-arkts.sh --stats tools/hooks/test-fixtures/BadSecurityKit.ets 2>&1)
if echo "$STATS" | grep -qE "By rule"; then
  assert_pass "BadSecurityKit --stats 输出 By rule 段"
else
  assert_fail "BadSecurityKit --stats 缺 By rule"
fi

# ─── 5) check-ohpm-deps 假包 fixture 必须 exit=2 ──────────
echo
echo "[5/6] check-ohpm-deps"
bash tools/check-ohpm-deps.sh tools/hooks/test-fixtures/bad-oh-package.json5 >/dev/null 2>&1
rc=$?
if [[ "$rc" == "2" ]]; then
  assert_pass "bad-oh-package.json5 → exit=2"
else
  assert_fail "bad-oh-package.json5 → exit=$rc (expected 2)"
fi

# ─── 6) install.sh --dry-run 不写文件 + generate-configs --check ─
echo
echo "[6/6] install/generate sanity"
TMP=$(mktemp -d)
HOAW_REPO_OWNER="" \
  bash tools/install.sh --dry-run --dir="$TMP" >/dev/null 2>&1 || true
file_count=$(find "$TMP" -type f 2>/dev/null | wc -l | tr -d ' ')
if [[ "$file_count" == "0" ]]; then
  assert_pass "install.sh --dry-run 不写文件"
else
  assert_fail "install.sh --dry-run 误写了 $file_count 个文件"
fi
rm -rf "$TMP"

if bash tools/generate-ai-configs.sh --check >/dev/null 2>&1; then
  assert_pass "generate-ai-configs.sh --check 通过"
else
  assert_fail "generate-ai-configs.sh --check 失败"
fi

# ─── 总结 ─────────────────────────────────────────────────
echo
echo "═══ 结果：${pass} passed, ${fail} failed ═══"
if [[ "$fail" -gt 0 ]]; then exit 1; fi
exit 0
