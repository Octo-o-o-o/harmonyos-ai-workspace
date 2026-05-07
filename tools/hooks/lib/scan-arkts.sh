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

# 解析参数
JSON_MODE="0"
STATS_MODE="0"
FILE=""
for arg in "$@"; do
  case "$arg" in
    --json) JSON_MODE="1" ;;
    --stats) STATS_MODE="1" ;;
    --help|-h) sed -n '2,17p' "$0"; exit 0 ;;
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

# v0.6: 提取 "ArkUI 类内部" 的行号集合
# STATE-002/009/008 等响应式相关规则只应在 ArkUI 装饰过的 class/struct 内部触发——
# 普通工具类（IDataSource / Store / EventBus / SecretStore 等）的 `this.X.push()`
# 不是状态变更，是普通数组操作。
#
# v0.7 修复（合并第四轮反馈）：
#   - 同行 `@Entry @Component struct Page {` v0.6 因 next 跳过被漏识别
#   - @CustomDialog / @Reusable v0.6 不在白名单
#   - 装饰器名单提到顶部变量便于扩展
ARKUI_DECORATORS='Component|ComponentV2|Observed|ObservedV2|Entry|CustomDialog|Reusable'
ARKUI_LINES_FILE="$(mktemp)"
trap 'rm -f "$TMP" "$ARKUI_LINES_FILE"' EXIT
awk -v decs="$ARKUI_DECORATORS" '
  BEGIN {
    in_arkui = 0; pending = 0; depth = 0
    arkui_re = "@(" decs ")"
    dec_re   = "^[[:space:]]*@(" decs ")([[:space:]]|$|\\()"
    sc_re    = "(struct|class)[[:space:]]+[A-Z]"
    ssc_re   = "^[[:space:]]*(export[[:space:]]+)?(struct|class)[[:space:]]+[A-Z]"
  }
  # 同行装饰器 + struct/class（v0.7 新增）
  # 例：`@Entry @Component struct Page {`、`@CustomDialog struct Dialog {`
  # 注意：不 next，让默认规则在该行做 brace tracking
  ($0 ~ /^[[:space:]]*@/) && ($0 ~ sc_re) {
    if ($0 ~ arkui_re) {
      in_arkui = 1; pending = 0; depth = 0
    } else {
      in_arkui = 0; pending = 0
    }
  }
  # 单独装饰器行（next 跳过 brace tracking——该行无 struct/class）
  ($0 ~ dec_re) && ($0 !~ sc_re) {
    pending = 1
    next
  }
  # struct/class 单独行（前一行可能是装饰器）
  $0 ~ ssc_re {
    if (pending) { in_arkui = 1; pending = 0; depth = 0 }
    else { in_arkui = 0 }
  }
  {
    if (in_arkui) print NR
    # 跟踪花括号深度，离开类时清状态
    n = length($0)
    for (i = 1; i <= n; i++) {
      c = substr($0, i, 1)
      if (c == "{") depth++
      else if (c == "}") { depth--; if (depth == 0) in_arkui = 0 }
    }
  }
' "$TMP" > "$ARKUI_LINES_FILE"

# 检查指定行号是否属于 ArkUI 类
in_arkui_class() {
  local ln="$1"
  [[ -z "$ln" ]] && return 1
  grep -qx "$ln" "$ARKUI_LINES_FILE" 2>/dev/null
}

# JSON 累积器（仅 JSON 模式使用；用临时文件避免 here-string + JQ 依赖）
JSON_BUF="$(mktemp)"

# JSON 安全转义（最小集：" \ 控制字符）
json_escape() {
  printf '%s' "$1" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read())[1:-1])' 2>/dev/null \
    || printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

# v0.5 inline-suppress：用户在违规上一行或同行写：
#   // scan-ignore: <RULE-ID>           只跳过该规则
#   // scan-ignore: <RULE1>,<RULE2>     跳过多条规则
#   // scan-ignore-line                 跳过本行所有规则
# 给用户一个"我已审、故意保留"的逃生口。
should_suppress() {
  local rule="$1" line="$2"
  [[ -z "$line" || "$line" -lt 1 ]] && return 1
  # 读"该行"和"上一行"原文（注意：这里读 $FILE 而非去注释后的 $TMP，
  # 因为 // 注释正是抑制标记的载体）
  local cur_line=""
  local prev_line=""
  cur_line=$(sed -n "${line}p" "$FILE" 2>/dev/null)
  if [[ "$line" -gt 1 ]]; then
    prev_line=$(sed -n "$((line - 1))p" "$FILE" 2>/dev/null)
  fi
  # scan-ignore-line 只匹配同行（顾名思义），不沿用到下一行
  if [[ -n "$cur_line" ]] && echo "$cur_line" | grep -qE '//[[:space:]]*scan-ignore-line\b'; then
    return 0
  fi
  # scan-ignore: RULE 既可以写同行（行尾注释），也可以写上一行
  for l in "$prev_line" "$cur_line"; do
    [[ -z "$l" ]] && continue
    if echo "$l" | grep -qE "//[[:space:]]*scan-ignore:[[:space:]]*[A-Z0-9-]*[[:space:],]*${rule}\b"; then
      return 0
    fi
  done
  return 1
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

# v0.6 collapse: 同文件同规则前 N 条原文输出，后续聚合
# 评审反馈：v0.5 只加了 hint 没真折叠。i18n DICT 文件 53 条 AGC-RJ-014 全输出
# 仍会埋掉真信号。
# JSON 模式不动（CI 要全部数据）；文本模式同规则前 COLLAPSE_THRESHOLD 条原文，
# 后续累加到 collapse counter，文件结束时统一输出"+N more"。
COLLAPSE_THRESHOLD=3
declare -A COLLAPSE_COUNT 2>/dev/null || COLLAPSE_COUNT=()

# 用临时文件兜底（macOS 的 bash 3.2 不支持 declare -A）
COLLAPSE_FILE="$(mktemp)"
trap 'rm -f "$TMP" "$ARKUI_LINES_FILE" "$COLLAPSE_FILE" "$JSON_BUF" 2>/dev/null' EXIT

count_for_rule() {
  local rule="$1" cnt=0
  if [[ -s "$COLLAPSE_FILE" ]]; then
    cnt=$(grep -c "^${rule} " "$COLLAPSE_FILE" 2>/dev/null) || cnt=0
  fi
  # 防御：grep 在某些 shell 下输出含换行
  cnt=${cnt//$'\n'/}
  printf '%d\n' "${cnt:-0}"
}

bump_rule() {
  local rule="$1"
  echo "${rule} 1" >> "$COLLAPSE_FILE"
}

# 决定是否输出本次命中的原文：
#   --json     总是 emit（CI 要全部数据）
#   --stats    永不 emit（仅汇总）
#   文本模式   同文件同规则前 COLLAPSE_THRESHOLD 条 emit；之后聚合
should_print_record() {
  local rule="$1"
  [[ "$JSON_MODE" == "1" ]] && return 0
  [[ "$STATS_MODE" == "1" ]] && return 1
  local seen
  seen=$(count_for_rule "$rule")
  [[ "$seen" -lt "$COLLAPSE_THRESHOLD" ]]
}

emit_high() {
  # inline-suppress 检查上移到 emit_*：抑制时既不输出也不计数
  if should_suppress "$1" "$2"; then return; fi
  if should_print_record "$1"; then
    emit_record "$1" "High" "$2" "$3" "$4"
  fi
  bump_rule "$1"
  violations_high=$((violations_high + 1))
}

emit_med() {
  if should_suppress "$1" "$2"; then return; fi
  if should_print_record "$1"; then
    emit_record "$1" "Medium" "$2" "$3" "$4"
  fi
  bump_rule "$1"
  violations_med=$((violations_med + 1))
}

# 抽出 grep 匹配的所有 line:content
scan_lines() {
  local pattern="$1"
  grep -nE "$pattern" "$TMP" || true
}

# ─── 规则集 ───────────────────────────────────────────

# STATE-002: 数组就地 mutation（push/pop/shift/unshift/splice/sort/reverse）
# v0.6: 仅在 @Component / @ComponentV2 / @Entry / @Observed / @ObservedV2 装饰的
# class 或 struct 内部触发——普通工具类（IDataSource / Store / EventBus 等）的
# `this.X.push()` 不是状态变更，是普通数组操作。评审者实测 scanner 自己的
# samples/templates/list/item-data-source.ets（IDataSource 标准实现）被误报。
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  if ! in_arkui_class "$ln"; then
    continue   # 非 ArkUI 类内部：普通数组操作，不报
  fi
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
# v0.5 修：评审反馈 PrivateTalk LlmClient 12 处误报——`Record<string, Object>` 上的索引赋值是合法的。
# 提取被索引的变量名，看同文件有没有 `<varname>: Record<...>` 或 `: Map<` 声明；有则跳过。
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  # 提取被索引的变量名（如 `partObj['type']` → partObj）
  var=$(echo "$content" | grep -oE '\b[a-zA-Z_]\w*\[["'\''][^"'\'']+["'\'']\]' | head -1 | sed 's/\[.*//')
  if [[ -n "$var" ]]; then
    # 同文件是否有 `var: Record<...>` 或 `var: Map<...>` 声明
    if grep -qE "\b${var}\s*:\s*(Record<|Map<)" "$TMP" 2>/dev/null; then
      continue
    fi
  fi
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

# ARKTS-016: 空 catch 块吞错
# v0.6 调整：评审者实测 15 处中 ~10 处是 cleanup/destroy/unlink 容错（合理），
# ~3 处 JSON.parse fallback（合理），仅 ~2 处真问题。
# 改为：只在文件**确含 await** 的场景报（说明在异步上下文，吞错风险更高）；
# 严重度从 High 降到 Medium；reason 加"如果是 cleanup 容错可加 scan-ignore"。
if grep -qE '\bawait\s' "$TMP" 2>/dev/null; then
  while IFS= read -r match; do
    [[ -z "$match" ]] && continue
    ln="${match%%:*}"
    content="${match#*:}"
    if echo "$content" | grep -qE 'catch\s*\([^)]*\)\s*\{\s*\}'; then
      emit_med "ARKTS-016" "$ln" "${content:0:80}" \
        "异步上下文中空 catch 吞错可能漏处理失败。如确认是 cleanup/destroy 容错可加 // scan-ignore: ARKTS-016"
    fi
  done < <(scan_lines 'catch\s*\(' | head -20)
fi

# STATE-009: Map / Set 就地 set / delete / clear 但外层是 @State
# v0.6 升级：原 v0.5 的 EXCLUDE_NAMES 前缀白名单是补丁。改用 in_arkui_class
# 上下文检查——只在 ArkUI 类内部触发。普通 class（PrefStore / SecretStore /
# RdbAdapter）的 `this.prefs.delete()` 是 KV/DB API 调用，永远不该报。
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  if ! in_arkui_class "$ln"; then
    continue
  fi
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

# PERF-002: ForEach 在长列表场景应用 LazyForEach
# v0.6 升级：评审者实测原"文件 > 80 行"判据 91% 误报率（settings 子页文件 200 行
# 但数据源只有 3-5 项）。改为数据源名启发式——只匹配暗示长列表的标识符。
# 数据源 ≥ 50 项 / 不可预知长度 / 来自 RDB / 网络分页 才该用 LazyForEach。
LONG_LIST_HINTS='messages|conversations|posts|feed|items|logs|records|history|comments|threads|notifications|chats|users|contacts'
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  # 提取 ForEach 第一个参数的标识符（数据源）
  source_var=$(echo "$content" | grep -oE 'ForEach\s*\(\s*(this\.)?[a-zA-Z_][a-zA-Z0-9_]*' | sed -E 's/.*\(\s*(this\.)?//')
  # 仅当数据源名暗示长列表时报
  if [[ -n "$source_var" ]] && echo "$source_var" | grep -qiE "^($LONG_LIST_HINTS)$"; then
    # 同文件含 LazyForEach 才算"已经用了"——如果完全没有，但数据源名是长列表则报
    if ! grep -qE 'LazyForEach' "$TMP" 2>/dev/null; then
      emit_med "PERF-002" "$ln" "${content:0:80}" \
        "数据源名 \"$source_var\" 暗示长列表。如条目 ≥ 50 / 来自 RDB / 网络分页，请改 LazyForEach + IDataSource"
    fi
  fi
done < <(scan_lines '\bForEach\s*\(' | head -10)

# STATE-006: V1 调用方双向绑定丢 $$
# v0.5 删除：评审者实测此规则启发式不足——"看到 @Link 就把所有 SomeComponent({ ... })
# 报"会刷屏。grep 跨语义不够，需要 AST。让 state-management SKILL 文档教即可，scanner
# 不再扫这条。如需重新启用，须接 ts-morph / tree-sitter。

# ─── v0.4 实战反馈新增（PrivateTalk M3-M12 真踩坑） ───────────────

# ARKTS-RECORD: Record<K,V> 字面量初始化触发 untyped-obj-literals
# v0.5 修：评审反馈空字面量 `= {}` 在 ArkTS 中合法且常见（PrivateTalk BackupManager
# 实际编译过）。规则真正想防的是含键值 `= { 'foo': 1 }` 的情况。
# 模式改成要求至少一个键值对（'k': 或 "k": 或 字段名:）。
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  ln="${match%%:*}"
  content="${match#*:}"
  emit_high "ARKTS-RECORD" "$ln" "${content:0:80}" \
    "Record<K,V> 含键值字面量初始化仍触发 arkts-no-untyped-obj-literals。改 Map<K,V>.set() 或先声明 class 再赋值。空 = {} 是合法的"
done < <(scan_lines ":\s*Record<[^>]+>\s*=\s*\{[[:space:]]*['\"a-zA-Z_]" | head -5)

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

# --stats 模式：仅按规则汇总命中数（CI 友好）
if [[ "$STATS_MODE" == "1" ]]; then
  if [[ -s "$COLLAPSE_FILE" ]]; then
    echo "By rule (file: $REL):"
    awk '{print $1}' "$COLLAPSE_FILE" | sort | uniq -c | sort -rn | sed 's/^/  /'
  else
    echo "No violations: $REL"
  fi
  if [[ "$violations_high" -gt 0 ]]; then exit 2
  elif [[ "$violations_med" -gt 0 ]]; then exit 1
  fi
  exit 0
fi

# 文本模式：collapse 汇总 + summary
# v0.6: 真 collapse —— 同文件同规则 ≥ COLLAPSE_THRESHOLD 条时，前几条原文已在 emit_*
# 输出，剩余的在这里聚合输出 "[+RULE-ID] N more in this file"。
# JSON 模式不动（CI 要全部数据）。
if [[ "$JSON_MODE" != "1" ]]; then
  # 按规则汇总，找出超过 threshold 的
  if [[ -s "$COLLAPSE_FILE" ]]; then
    awk '{print $1}' "$COLLAPSE_FILE" | sort | uniq -c | while read -r cnt rule; do
      if [[ "$cnt" -gt "$COLLAPSE_THRESHOLD" ]]; then
        more=$((cnt - COLLAPSE_THRESHOLD))
        printf '[+%s] %d more in this file (use `// scan-ignore: %s` to silence)\n' \
          "$rule" "$more" "$rule" >&2
      fi
    done
  fi

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
