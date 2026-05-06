#!/usr/bin/env bash
# scan-arkts.sh — 对单个 .ets / .ts 文件做 grep-based ArkTS 反模式扫描
#
# Usage:
#   bash scan-arkts.sh path/to/file.ets
#
# 输出：每条违规一行
#   [<RULE-ID> · <severity>] <relative-path>:<line>: <reason>
#
# 退出码：
#   0 - 无违规
#   1 - 有 Medium / Low
#   2 - 有 Critical / High（Claude Code 默认会把 stderr 回喂给 AI）

set -u

FILE="${1:-}"
if [[ -z "$FILE" ]]; then
  echo "scan-arkts.sh: 需要文件路径参数" >&2
  exit 64
fi

if [[ ! -f "$FILE" ]]; then
  # 文件不存在不报错（可能是 hook 被触发但文件被删）
  exit 0
fi

# 仅扫描 .ets / .ts（其他类型直接跳过）
case "$FILE" in
  *.ets|*.ts) ;;
  *) exit 0 ;;
esac

# 输出工具
violations_high=0
violations_med=0

# 计算相对路径（更可读）
REL="$FILE"
if [[ -n "${HOOK_PROJECT_DIR:-}" && "$FILE" == "$HOOK_PROJECT_DIR"/* ]]; then
  REL="${FILE#$HOOK_PROJECT_DIR/}"
fi

# 排除注释行的辅助：用 awk 过滤
strip_comments() {
  awk '
    BEGIN { in_block = 0 }
    {
      line = $0
      if (in_block) {
        if (match(line, /\*\//)) {
          line = substr(line, RSTART + RLENGTH)
          in_block = 0
        } else {
          print ""
          next
        }
      }
      while (match(line, /\/\*/)) {
        end = index(substr(line, RSTART + 2), "*/")
        if (end > 0) {
          line = substr(line, 1, RSTART - 1) substr(line, RSTART + 2 + end + 1)
        } else {
          line = substr(line, 1, RSTART - 1)
          in_block = 1
          break
        }
      }
      sub(/\/\/.*/, "", line)
      print line
    }
  ' "$1"
}

# 临时去注释文件
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
strip_comments "$FILE" > "$TMP"

emit_high() {
  local rule="$1" line="$2" snippet="$3" reason="$4"
  printf '[%s · High] %s:%s: %s\n  ↳ %s\n' \
    "$rule" "$REL" "$line" "$snippet" "$reason" >&2
  violations_high=$((violations_high + 1))
}

emit_med() {
  local rule="$1" line="$2" snippet="$3" reason="$4"
  printf '[%s · Medium] %s:%s: %s\n  ↳ %s\n' \
    "$rule" "$REL" "$line" "$snippet" "$reason" >&2
  violations_med=$((violations_med + 1))
}

# 抽出 grep 匹配的所有 line:content
scan_lines() {
  local pattern="$1"
  grep -nE "$pattern" "$TMP" || true
}

# ─── 规则集 ───────────────────────────────────────────

# STATE-002: 数组就地 mutation（push/pop/shift/unshift/splice/sort/reverse）
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_high "STATE-002" "$ln" "${content:0:80}" \
    "数组就地 mutation 不触发重渲染。改写：this.X = [...this.X, item] / this.X.filter(...) / this.X.map(...)"
done < <(scan_lines '\bthis\.[a-zA-Z_][a-zA-Z0-9_]*\.(push|pop|shift|unshift|splice|sort|reverse)\s*\(')

# ARKTS-001: any / unknown / var
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_high "ARKTS-001" "$ln" "${content:0:80}" \
    "ArkTS 禁用 any / unknown / var。改用具体类型 + let / const"
done < <(scan_lines '(:\s*any\b|:\s*unknown\b|^\s*var\s|[\(,;]\s*var\s)')

# ARKTS-014: 旧式 @ohos.* import
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_med "ARKTS-014" "$ln" "${content:0:80}" \
    "推荐改 @kit.* 命名空间（如 @kit.NetworkKit / @kit.ArkUI）。@ohos.* 仍可用但属旧式"
done < <(scan_lines "from\s+['\"]@ohos\.")

# ARKTS-012: console.* 而不是 hilog
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_med "ARKTS-012" "$ln" "${content:0:80}" \
    "鸿蒙日志统一用 hilog。改写：hilog.info(DOMAIN, 'Tag', '%{public}s', msg)"
done < <(scan_lines '\bconsole\.(log|info|warn|error|debug)\s*\(')

# ARKTS-009: for...in
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_high "ARKTS-009" "$ln" "${content:0:80}" \
    "ArkTS 禁用 for...in。改写：for (const k of Object.keys(o)) { ... } 或直接 for (let i=0; i<arr.length; i++)"
done < <(scan_lines '\bfor\s*\(\s*(const|let|var)\s+\w+\s+in\s')

# ARKTS-008: delete
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_med "ARKTS-008" "$ln" "${content:0:80}" \
    "ArkTS 禁 delete 操作符。把字段类型设为 T | null 后赋 null"
done < <(scan_lines '\bdelete\s+\w+')

# ARKTS-005: function 表达式
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_med "ARKTS-005" "$ln" "${content:0:80}" \
    "ArkTS 禁 function 表达式。改写：const f = (x: T): R => { ... }"
done < <(scan_lines '=\s*function\s*\(')

# ARKTS-007: regex 字面量（粗略：/.../[gimsy]+）
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  # 排除注释 // 路径
  if echo "$content" | grep -qE '/[^/[:space:]][^/]*/[gimsuy]+\b'; then
    emit_med "ARKTS-007" "$ln" "${content:0:80}" \
      "ArkTS 禁 regex 字面量。改写：new RegExp('pattern', 'flags')"
  fi
done < <(scan_lines '/[^/[:space:]][^/]*/[gimsuy]+\b')

# ARKTS-004: 解构赋值
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_med "ARKTS-004" "$ln" "${content:0:80}" \
    "ArkTS 不支持解构赋值。改写：const a = obj.a; const b = obj.b;"
done < <(scan_lines '^\s*(const|let|var)\s*[\{\[]')

# ARKTS-003: 字符串字面量索引访问 obj['key']
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  # 跳过 Map / Record 标准访问（不会用 [] 访问）
  emit_med "ARKTS-003" "$ln" "${content:0:80}" \
    "ArkTS 禁动态索引。如果是已知字段用 obj.field；动态键改用 Map<K,V>.get(k)"
done < <(scan_lines '[a-zA-Z_]\w*\[["'\''][^"'\'']+["'\'']\]')

# STATE-001: V1 与 V2 装饰器同文件
v1_count=0
v2_count=0
v1_count=$(grep -cE '^@(Component|Entry)$|^@(Component|Entry)[[:space:]]' "$TMP" 2>/dev/null) || v1_count=0
v2_count=$(grep -cE '@ComponentV2|@Local[[:space:]]|@Param[[:space:]]|@Once[[:space:]]|@Event[[:space:]]|@Provider\(\)|@Consumer\(\)|@ObservedV2|@Trace[[:space:]]|@Monitor\(|@Computed[[:space:]]' "$TMP" 2>/dev/null) || v2_count=0
if [[ "${v1_count:-0}" -gt 0 && "${v2_count:-0}" -gt 0 ]]; then
  emit_high "STATE-001" "1" "(全文)" \
    "同文件混用 V1（@Component/@State/@Prop/@Link）与 V2（@ComponentV2/@Local/@Param/@Event）。请二选一"
fi

# STATE-008: build() 方法内部副作用（粗略）
# 检测 build() { ... } 内的 console / fetch / await / setTimeout
state008_out="$(awk '
  /[[:space:]]build[[:space:]]*\([[:space:]]*\)[[:space:]]*\{/ { in_build=1; depth=1; next }
  in_build {
    for (i=1; i<=length($0); i++) {
      c = substr($0, i, 1)
      if (c == "{") depth++
      if (c == "}") { depth--; if (depth==0) { in_build=0; break } }
    }
    if ($0 ~ /console\.|fetch\(|[[:space:]]await[[:space:]]|setTimeout\(|setInterval\(/) {
      printf("%d:%s\n", NR, $0)
    }
  }
' "$TMP")"
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_high "STATE-008" "$ln" "${content:0:80}" \
    "build() 必须是纯函数，不要在内部调副作用。把副作用挪到 aboutToAppear() / onPageShow() / 事件回调"
done <<<"$state008_out"

# ARKTS-015: 一元 + 转字符串
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_med "ARKTS-015" "$ln" "${content:0:80}" \
    "ArkTS 禁一元 + 转换。改写：parseInt(s, 10) 或 Number(s)"
done < <(scan_lines '[^a-zA-Z0-9_)\]]\+\s*[a-zA-Z_]\w*\b' | grep -E '\+\s*[a-zA-Z_]' | grep -vE '\+\s*=' || true)

# ─── 总结 ───────────────────────────────────────────

if [[ "$violations_high" -gt 0 ]]; then
  printf '\n[summary] %s · High: %d · Medium: %d\n' "$REL" "$violations_high" "$violations_med" >&2
  exit 2
elif [[ "$violations_med" -gt 0 ]]; then
  printf '\n[summary] %s · Medium: %d\n' "$REL" "$violations_med" >&2
  exit 1
fi

exit 0
