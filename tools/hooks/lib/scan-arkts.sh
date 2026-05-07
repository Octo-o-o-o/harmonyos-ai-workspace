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

# 解析参数：--json 切到 JSON 输出模式，其余视为文件路径
JSON_MODE="0"
FILE=""
for arg in "$@"; do
  case "$arg" in
    --json) JSON_MODE="1" ;;
    --help|-h) sed -n '2,15p' "$0"; exit 0 ;;
    *) [[ -z "$FILE" ]] && FILE="$arg" ;;
  esac
done

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

# JSON 累积器（仅 JSON 模式使用；用临时文件避免 here-string + JQ 依赖）
JSON_BUF="$(mktemp)"

# JSON 安全转义（最小集：" \ 控制字符）
json_escape() {
  printf '%s' "$1" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read())[1:-1])' 2>/dev/null \
    || printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

emit_record() {
  local rule="$1" sev="$2" line="$3" snippet="$4" reason="$5"
  if [[ "$JSON_MODE" == "1" ]]; then
    {
      printf '{'
      printf '"rule":"%s",' "$rule"
      printf '"severity":"%s",' "$sev"
      printf '"file":"%s",' "$(json_escape "$REL")"
      printf '"line":%s,' "$line"
      printf '"snippet":"%s",' "$(json_escape "${snippet:0:120}")"
      printf '"reason":"%s"' "$(json_escape "$reason")"
      printf '}\n'
    } >>"$JSON_BUF"
  else
    printf '[%s · %s] %s:%s: %s\n  ↳ %s\n' \
      "$rule" "$sev" "$REL" "$line" "$snippet" "$reason" >&2
  fi
}

emit_high() {
  emit_record "$1" "High" "$2" "$3" "$4"
  violations_high=$((violations_high + 1))
}

emit_med() {
  emit_record "$1" "Medium" "$2" "$3" "$4"
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

# ─── 新增规则（v0.3 扩展，Top 7 高把握） ────────────────────

# KIT-001: Network Kit `http.createHttp()` 用完未 destroy
# 简化检测：见 createHttp() 但同文件没出现 destroy()
if grep -qE 'http\.createHttp\(\)' "$TMP" 2>/dev/null && ! grep -qE '\.destroy\(\)' "$TMP" 2>/dev/null; then
  ln_kit=$(grep -nE 'http\.createHttp\(\)' "$TMP" | head -1 | cut -d: -f1)
  emit_med "KIT-001" "${ln_kit:-1}" "$(grep -E 'http\.createHttp\(\)' "$TMP" | head -1)" \
    "@kit.NetworkKit 的 http 实例使用完应调 destroy() 释放；本文件未见 destroy()"
fi

# PERF-001: forEach + await 反模式（无法并发也无法保序）
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_high "PERF-001" "$ln" "${content:0:80}" \
    "forEach 内 await 既不并发也不保序。要并发用 Promise.all(arr.map(...))；要顺序用 for-of"
done < <(scan_lines '\.forEach\s*\(\s*async' | head -10)

# ARKTS-013: console.log 但不带 hilog 形式
# （ARKTS-012 已检 console.*，此条更细：检 throw new Error 后丢弃 stack）
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  # 排除 throw new Error("...") 这种正常用法；只命中 catch 内吞错
  if echo "$content" | grep -qE 'catch\s*\([^)]*\)\s*\{\s*\}'; then
    emit_high "ARKTS-016" "$ln" "${content:0:80}" \
      "空 catch 块吞掉异常会让上架审核失败稳定性测试。最少打 hilog.error 或重抛"
  fi
done < <(scan_lines 'catch\s*\(' | head -20)

# STATE-009: Map / Set 就地 set / delete / clear 但外层是 @State
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_high "STATE-009" "$ln" "${content:0:80}" \
    "Map / Set 就地 set / delete / clear 不触发重渲染。改写：const next = new Map(this.m); next.set(...); this.m = next;"
done < <(scan_lines '\bthis\.[a-zA-Z_]\w*\.(set|delete|clear)\s*\(' | head -10)

# SEC-001: 硬编码看起来像 token / api-key / secret 的字符串字面量
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  # 只匹配明显的赋值表达式，避免 import / 类型注解假阳
  if echo "$content" | grep -qE '(token|secret|apiKey|api_key|password)[[:space:]]*[:=][[:space:]]*["'\''][A-Za-z0-9+/=_-]{16,}["'\'']'; then
    emit_high "SEC-001" "$ln" "${content:0:80}" \
      "看似硬编码密钥/口令/Token，长度 ≥ 16。请挪到环境变量或 secure storage（@kit.AbilityKit 的 EncryptedPreferences）"
  fi
done < <(scan_lines '(token|secret|apiKey|api_key|password)' | head -20)

# COMPAT-001: 调到看起来像 API 21+ 新 Kit 但未做 canIUse 守护
# 简化检测：用了 @kit.Foo 但全文没 canIUse
if grep -qE 'from[[:space:]]+["\'']@kit\.' "$TMP" 2>/dev/null && ! grep -qE 'canIUse\s*\(' "$TMP" 2>/dev/null; then
  # 仅在导入了较"新"的 Kit 时提示，避免每个文件都报
  if grep -qE 'from[[:space:]]+["\'']@kit\.(BackgroundTasksKit|DistributedDataObject|DeviceManagerKit|IAPKit|HuksAuthKit)["\'']' "$TMP" 2>/dev/null; then
    ln_compat=$(grep -nE 'from[[:space:]]+["\'']@kit\.' "$TMP" | head -1 | cut -d: -f1)
    emit_med "COMPAT-001" "${ln_compat:-1}" "(import @kit.*)" \
      "导入了较新的 Kit 但未见 canIUse('SystemCapability.X') 守护；如果 minSDK < 21 会在老设备崩"
  fi
fi

# ─── v0.3 新增 7 条规则（高把握，假阳性低） ──────────────────────────

# SEC-002: hilog %{public} 输出敏感字段
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  if echo "$content" | grep -qE 'hilog\.[a-z]+\([^,]+,[^,]+,[^,]*%\{public\}.*?,[^)]*\b(token|password|secret|apiKey|api_key|身份证|idCard|phone)' ; then
    emit_high "SEC-002" "$ln" "${content:0:80}" \
      "hilog 用 %{public} 输出敏感字段（token / password / 身份证等）会泄漏到日志。改 %{private} 或脱敏后再打"
  fi
done < <(scan_lines 'hilog\.[a-z]+\(' | head -20)

# SEC-007: 弱算法（MD5 / SHA1 / DES）
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_med "SEC-007" "$ln" "${content:0:80}" \
    "MD5 / SHA1 / DES 是弱算法，AGC 审核会被拒。改 SHA-256+ / AES-GCM（@kit.CryptoArchitectureKit）"
done < <(scan_lines '\b(MD5|SHA1|DES)\b' | grep -vE 'SHA1?256|SHA-?256|DESC|description' | head -10)

# DB-001: ResultSet / RdbStore 取出后无 close
if grep -qE '\.getResultSet\s*\(|\.getRdbStore\s*\(' "$TMP" 2>/dev/null && ! grep -qE '\.close\s*\(\s*\)' "$TMP" 2>/dev/null; then
  ln_db=$(grep -nE '\.getResultSet\s*\(|\.getRdbStore\s*\(' "$TMP" | head -1 | cut -d: -f1)
  emit_high "DB-001" "${ln_db:-1}" "$(grep -E '\.getResultSet\s*\(|\.getRdbStore\s*\(' "$TMP" | head -1 | sed 's/^[[:space:]]*//')" \
    "ResultSet / RdbStore 取出后未见 .close()。AGC 提审会卡稳定性测试。用 try/finally 保证释放"
fi

# KIT-002: ImageSource 解码后未 release
if grep -qE 'createImageSource\s*\(|imageSource' "$TMP" 2>/dev/null && ! grep -qE '\.release\s*\(\s*\)' "$TMP" 2>/dev/null; then
  ln_img=$(grep -nE 'createImageSource\s*\(' "$TMP" | head -1 | cut -d: -f1)
  if [[ -n "$ln_img" ]]; then
    emit_med "KIT-002" "$ln_img" "$(grep -E 'createImageSource\s*\(' "$TMP" | head -1 | sed 's/^[[:space:]]*//')" \
      "ImageSource 解码后应调 .release() 释放原生缓冲；本文件未见 release"
  fi
fi

# AGC-RJ-014: UI 中文字符串硬编码（应走 $r('app.string.xxx')）
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_med "AGC-RJ-014" "$ln" "${content:0:80}" \
    "UI 中含硬编码中文字符串。AGC 审核要求走资源 \$r('app.string.xxx') 以支持国际化"
done < <(scan_lines 'Text\s*\(\s*['\''"][^'\''"\$]*[一-鿿]' | head -10)

# PERF-002: 使用了 ForEach 但数据源是 Array 类型且行数 > 50（提示用 LazyForEach）
foreach_lines=$(grep -cE '\bForEach\s*\(' "$TMP" 2>/dev/null) || foreach_lines=0
if [[ "${foreach_lines:-0}" -gt 0 ]] && ! grep -qE 'LazyForEach' "$TMP" 2>/dev/null; then
  total_lines=$(wc -l < "$TMP")
  if [[ "$total_lines" -gt 80 ]]; then
    ln_fe=$(grep -nE '\bForEach\s*\(' "$TMP" | head -1 | cut -d: -f1)
    emit_med "PERF-002" "${ln_fe:-1}" "$(grep -E '\bForEach\s*\(' "$TMP" | head -1 | sed 's/^[[:space:]]*//')" \
      "ForEach 适合短列表；超过 50 项时用 LazyForEach + IDataSource 才不会一次性渲染所有项"
  fi
fi

# STATE-006: V1 调用方双向绑定丢 $$
# 检测：V1 子组件用 @Link，但调用方写 `Child({ x: this.y })` 而不是 `Child({ x: $$this.y })`
# 简化：仅当文件含 @Link 时给提示，要求人核查
if grep -qE '@Link\s+\w+' "$TMP" 2>/dev/null; then
  # 查所有形如 SomeComponent({ ... }) 但未见 $$
  while IFS= read -r match; do
    [[ -z "$match" ]] && continue
    ln="${match%%:*}"
    content="${match#*:}"
    # 排除已用 $$ 的行
    if echo "$content" | grep -qvE '\$\$'; then
      emit_med "STATE-006" "$ln" "${content:0:80}" \
        "本文件含 @Link 装饰器，调用子组件时双向绑定字段必须用 \$\$x 而非 x，否则单向"
    fi
  done < <(scan_lines '^[[:space:]]*[A-Z][a-zA-Z0-9_]*\s*\(\s*\{' | head -5)
fi

# ─── v0.4 实战反馈新增（PrivateTalk M3-M12 真踩坑） ───────────────

# ARKTS-RECORD-LITERAL: Record<K,V> 字面量初始化也违反 untyped-obj-literals
# AI 常以为 "Record 已经有类型了" 就能直接 = { k: v }，但 ArkTS 仍要求显式 class
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_high "ARKTS-RECORD" "$ln" "${content:0:80}" \
    "Record<K,V> 字面量初始化仍触发 arkts-no-untyped-obj-literals。改 Map<K,V>.set() 或先声明 class 再赋值"
done < <(scan_lines ':\s*Record<[^>]+>\s*=\s*\{' | head -5)

# ARKTS-AWAIT-TRY: 非 try 块内的 await 触发 hvigorw "Function may throw exceptions"
# 简化检测：扫所有 await 行；如果**整个文件没有 try { ... }**，提示
if grep -qE '\bawait\s' "$TMP" 2>/dev/null && ! grep -qE '\btry\s*\{' "$TMP" 2>/dev/null; then
  ln_aw=$(grep -nE '\bawait\s' "$TMP" | head -1 | cut -d: -f1)
  emit_med "ARKTS-AWAIT-TRY" "${ln_aw:-1}" "$(grep -E '\bawait\s' "$TMP" | head -1 | sed 's/^[[:space:]]*//' | head -c 80)" \
    "本文件含 await 但全文无 try 块。ArkTS 严格模式下 codeLinter 会报 'Function may throw exceptions'"
fi

# ARKTS-DEPRECATED-PICKER: HarmonyOS 6 起 picker.PhotoViewPicker 已弃用
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_high "ARKTS-DEPRECATED-PICKER" "$ln" "${content:0:80}" \
    "picker.PhotoViewPicker 在 HarmonyOS 6 已弃用。改用 photoAccessHelper.PhotoViewPicker（@kit.MediaLibraryKit）"
done < <(scan_lines '\bpicker\.PhotoViewPicker\b' | head -3)

# ARKTS-DEPRECATED-DECODE: util.TextDecoder.decodeWithStream 已弃用
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_high "ARKTS-DEPRECATED-DECODE" "$ln" "${content:0:80}" \
    "decodeWithStream 已弃用。改用 decoder.decodeToString(buf, { stream: true })"
done < <(scan_lines '\.decodeWithStream\s*\(' | head -3)

# ARKTS-NO-UNION-CONTENT: ArkTS 不允许 string | array 这类 union 字段（如 OpenAI Vision content）
# 检测：interface/class 字段写 `: string | <T>[]` 或 `: string | object[]`
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_high "ARKTS-NO-UNION-CONTENT" "$ln" "${content:0:80}" \
    "ArkTS 不支持 string|object[] 这类 union 字段。改用双字段（contentText / contentParts）+ 自定义序列化"
done < <(scan_lines ':\s*string\s*\|\s*[A-Za-z]+\s*\[' | head -5)

# STRING-JSON-EMPTY: string.json 空数组（删冲突项后留空数组会编译失败）
case "$FILE" in
  */resources/*/element/string.json)
    if grep -qE '"string"\s*:\s*\[\s*\]' "$TMP" 2>/dev/null; then
      ln_sj=$(grep -nE '"string"\s*:\s*\[' "$TMP" | head -1 | cut -d: -f1)
      emit_high "STRING-JSON-EMPTY" "${ln_sj:-1}" '"string": []' \
        'string.json 的 "string" 数组不允许为空。删冲突项后必须留至少一个 placeholder 条目'
    fi
    ;;
esac

# ─── 总结 ───────────────────────────────────────────

# JSON 模式：把累积的 record 拼成数组输出到 stdout
if [[ "$JSON_MODE" == "1" ]]; then
  if [[ -s "$JSON_BUF" ]]; then
    printf '['
    awk 'BEGIN{first=1} {if(first){first=0}else{printf ","}; printf "%s", $0}' "$JSON_BUF"
    printf ']\n'
  else
    printf '[]\n'
  fi
  rm -f "$JSON_BUF"
fi

# 文本模式：summary
if [[ "$JSON_MODE" != "1" ]]; then
  if [[ "$violations_high" -gt 0 ]]; then
    printf '\n[summary] %s · High: %d · Medium: %d\n' "$REL" "$violations_high" "$violations_med" >&2
  elif [[ "$violations_med" -gt 0 ]]; then
    printf '\n[summary] %s · Medium: %d\n' "$REL" "$violations_med" >&2
  fi
fi

# 退出码（两种模式都用）
if [[ "$violations_high" -gt 0 ]]; then
  exit 2
elif [[ "$violations_med" -gt 0 ]]; then
  exit 1
fi

exit 0
