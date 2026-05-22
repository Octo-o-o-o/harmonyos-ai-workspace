#!/usr/bin/env bash
# generate-ai-configs.sh — 从 .claude/skills/ + AGENTS.md 拼接出其他 AI 工具的配置
#
# 当前采用**多文件 fan-out**：
#   - 不再生成单个 29KB 大文件（Cursor 触发精度低、Copilot code-review 会截断）
#   - 按 SKILL 切到多个文件，每个文件用 globs / applyTo 精准触发
#   - root 入口控制在 4KB 内（Copilot 安全区）
#
# 生成产物：
#   .cursor/rules/harmonyos-core.mdc        alwaysApply: true，硬约束精华
#   .cursor/rules/harmonyos-arkts.mdc       globs: **/*.ets,**/*.ts
#   .cursor/rules/harmonyos-state.mdc       globs: **/*.ets
#   .cursor/rules/harmonyos-build.mdc       globs: **/oh-package.json5,**/module.json5,**/build-profile.json5
#   .cursor/rules/harmonyos-runtime.mdc     globs: **/module.json5,**/resources/**/*.json
#   .cursor/rules/harmonyos-sign.mdc        globs: **/AppScope/app.json5
#
#   .github/copilot-instructions.md         < 4KB，硬约束精华 + 引导到 instructions/
#   .github/instructions/arkts.instructions.md     applyTo: **/*.ets,**/*.ts
#   .github/instructions/state.instructions.md     applyTo: **/*.ets
#   .github/instructions/build.instructions.md     applyTo: **/oh-package.json5,**/module.json5,**/build-profile.json5
#   .github/instructions/runtime.instructions.md   applyTo: **/module.json5,**/resources/**
#   .github/instructions/sign-publish.instructions.md  applyTo: **/AppScope/app.json5
#
# 不在默认 fan-out 中的 3 个领域专项 skill（web-bridge / multimodal-llm / harmonyos-review）：
#   - Claude Code 通过 frontmatter 自动触发
#   - 其他工具用户用到时手动读 .claude/skills/<name>/SKILL.md
#   - 设计原因：这 3 个对绝大多数项目是低频，always-on fan-out 会膨胀上下文
#
# 用法：
#   bash tools/generate-ai-configs.sh                       # 默认生成 cursor + copilot
#   bash tools/generate-ai-configs.sh --targets=cursor
#   bash tools/generate-ai-configs.sh --check               # 只校验源文件齐全
#   bash tools/generate-ai-configs.sh --clean               # 先删除旧的单文件再生成
#
# 退出码：0 成功 / 2 源缺失或写入失败

set -eu

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
info() { printf "${BLUE}[i]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
err()  { printf "${RED}[✗]${NC} %s\n" "$*"; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

TARGETS="cursor,copilot"
CHECK_ONLY="0"
CLEAN="0"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --targets=*) TARGETS="${1#*=}"; shift ;;
    --check)     CHECK_ONLY="1"; shift ;;
    --clean)     CLEAN="1"; shift ;;
    -h|--help)   sed -n '2,32p' "$0"; exit 0 ;;
    *) shift ;;
  esac
done

# ─── 源文件清单 ───────────────────────────────────────────────
SKILL_ARKTS=".claude/skills/arkts-rules/SKILL.md"
SKILL_STATE=".claude/skills/state-management/SKILL.md"
SKILL_BUILD=".claude/skills/build-debug/SKILL.md"
SKILL_SIGN=".claude/skills/signing-publish/SKILL.md"
SKILL_RUNTIME=".claude/skills/runtime-pitfalls/SKILL.md"
AGENTS_MD="AGENTS.md"

REQUIRED_SOURCES=("$SKILL_ARKTS" "$SKILL_STATE" "$SKILL_BUILD" "$SKILL_SIGN" "$SKILL_RUNTIME" "$AGENTS_MD")

missing=0
for f in "${REQUIRED_SOURCES[@]}"; do
  if [[ ! -f "$f" ]]; then
    err "源文件缺失: $f"
    missing=$((missing + 1))
  fi
done
[[ "$missing" -gt 0 ]] && { err "请先确保所有源 SKILL.md 与 AGENTS.md 都存在"; exit 2; }
[[ "$CHECK_ONLY" == "1" ]] && { ok "所有源齐全"; exit 0; }

# ─── 工具函数 ─────────────────────────────────────────────────
strip_frontmatter() {
  # 剥掉 markdown frontmatter（首尾 ---）
  local f="$1"
  awk '
    BEGIN { fm = 0; started = 0 }
    NR == 1 && /^---$/ { fm = 1; next }
    fm == 1 && /^---$/ { fm = 2; next }
    fm == 1 { next }
    { print }
  ' "$f"
}

# ─── 核心硬约束（< 4KB 控制版） ───────────────────────────────
# 这段是手写而非从源文件抽取——AGENTS.md 是 6.7KB 放不进 Copilot 4KB 安全区
build_core_essence() {
  cat <<'EOF'
> 平台：HarmonyOS 6 系列（API 22 / 21 现行稳定，API 23 Developer Beta）
> ArkTS + ArkUI 声明式 + Stage 模型

**训练数据警告**：LLM 对 ArkTS 训练数据稀缺，**默认会写出 TypeScript 风格但 ArkTS 编译器拒绝的代码**。

## 绝对硬约束

### 1. 禁止 TS 特性

`any` · `var` · 解构赋值 · 对象字面量无类型注解 · `obj['key']` 动态访问 · `delete` · `for...in` · `/regex/` · function 表达式 · `#` 私有字段 · 索引签名 · 结构性类型 · Symbol · 未初始化的类字段

### 2. Import 用 `@kit.*` 路径

```typescript
// ✅
import { http } from '@kit.NetworkKit';
import { window } from '@kit.ArkUI';
// ⚠️ 旧式（仍可编译，但避免）
import http from '@ohos.net.http';
```

### 3. 状态更新**必须替换引用**（最高频 bug）

```typescript
// ❌ 不会触发重渲染：
this.list.push(x);
this.user.name = 'Alice';

// ✅ 必须新建引用：
this.list = [...this.list, x];
this.user = { ...this.user, name: 'Alice' };
```

V1：嵌套对象用 `@Observed` 类 + `@ObjectLink`；V2：`@ObservedV2` 类 + `@Trace` 字段。

### 4. V1 与 V2 状态管理**绝不混用**

一个 `.ets` 文件要么全 V1（`@Component @State @Prop @Link`），要么全 V2（`@ComponentV2 @Local @Param`）。**默认用 V1**，用户明确要求才切 V2。

### 5. 文件后缀语义

- `.ets` 含 UI（`@Component` / `build()`）
- `.ts` 纯逻辑
- 不要把 UI 写到 `.ts`

### 6. 不能 import npm 包

`axios` / `lodash` / `moment` 等**不存在于鸿蒙生态**。HTTP 用 `@kit.NetworkKit`，日期工具自写或用 `@kit.LocalizationKit`。

### 7. 改完代码必跑

```bash
ohpm install
hvigorw codeLinter
hvigorw assembleHap -p buildMode=debug
```

### 8. 不要发明 API

ArkTS / Kit API 在 API 12 → 22 多次变化，**写 API 前先在 `upstream-docs/openharmony-docs/zh-cn/application-dev/reference/` 验证签名**。不确定时告诉用户「我无法验证此 API 当前形态」，**不要编代码**。

## 详细规则按场景自动激活

| 编辑文件 | 自动激活的详细规则 |
| --- | --- |
| `.ets` / `.ts` | ArkTS 严格规则 + 状态管理 |
| `oh-package.json5` / `module.json5` / `build-profile.json5` | 构建调试 + 依赖校验 |
| `resources/**/*.json` / `module.json5` | 运行时装配陷阱 |
| `AppScope/app.json5` | 签名与上架 |

需要 Web 桥 / LLM SSE / 代码审查时，手动读 `.claude/skills/{web-bridge,multimodal-llm,harmonyos-review}/SKILL.md`。
EOF
}

# 生成单个 mdc 文件
gen_cursor_mdc() {
  local out="$1" desc="$2" globs="$3" always="$4" body_cmd="$5"
  mkdir -p "$(dirname "$out")"
  {
    echo "---"
    echo "description: $desc"
    if [[ -n "$globs" ]]; then
      echo "globs:"
      IFS=',' read -ra G <<<"$globs"
      for g in "${G[@]}"; do echo "  - \"$g\""; done
    fi
    echo "alwaysApply: $always"
    echo "---"
    echo
    eval "$body_cmd"
    echo
    echo "---"
    echo "> 由 \`tools/generate-ai-configs.sh\` 自动生成。**请勿手动编辑**——改源文件后重跑。"
  } > "$out"
  local size; size=$(wc -c < "$out" | tr -d ' ')
  ok "$out (${size} bytes)"
}

# 生成单个 instructions.md 文件
gen_copilot_instr() {
  local out="$1" desc="$2" apply_to="$3" body_cmd="$4"
  mkdir -p "$(dirname "$out")"
  {
    echo "---"
    echo "description: $desc"
    echo "applyTo: \"$apply_to\""
    echo "---"
    echo
    eval "$body_cmd"
    echo
    echo "---"
    echo "> 由 \`tools/generate-ai-configs.sh\` 自动生成。**请勿手动编辑**——改源文件后重跑。"
  } > "$out"
  local size; size=$(wc -c < "$out" | tr -d ' ')
  ok "$out (${size} bytes)"
}

# ─── Body 函数（各 skill 内容） ───────────────────────────────
body_arkts() { strip_frontmatter "$SKILL_ARKTS"; }
body_state() { strip_frontmatter "$SKILL_STATE"; }
body_build() { strip_frontmatter "$SKILL_BUILD"; }
body_runtime() { strip_frontmatter "$SKILL_RUNTIME"; }
body_sign() { strip_frontmatter "$SKILL_SIGN"; }
body_core() { build_core_essence; }

# ─── 清理旧文件 ───────────────────────────────────────────────
clean_old() {
  info "清理旧的单文件 fan-out 产物"
  rm -f .cursor/rules/harmonyos.mdc 2>/dev/null && info "  · removed .cursor/rules/harmonyos.mdc" || true
  # 旧版生成的 instructions/ 不存在，不需处理
}
[[ "$CLEAN" == "1" ]] && clean_old

# ─── 生成 Cursor ──────────────────────────────────────────────
generate_cursor() {
  info "生成 .cursor/rules/*.mdc（5 个文件）"

  gen_cursor_mdc \
    ".cursor/rules/harmonyos-core.mdc" \
    "HarmonyOS / ArkTS 硬约束精华。always-on，凡是写鸿蒙代码都先看这个。" \
    "" "true" "body_core"

  gen_cursor_mdc \
    ".cursor/rules/harmonyos-arkts.mdc" \
    "ArkTS 严格语法规则、TS → ArkTS 反模式改写、inline suppress。编辑 .ets / .ts 时激活。" \
    "**/*.ets,**/*.ts" "false" "body_arkts"

  gen_cursor_mdc \
    ".cursor/rules/harmonyos-state.mdc" \
    "ArkUI 状态管理：替换引用铁律、V1/V2 对照、@Observed/@Trace 用法。编辑 .ets 时激活。" \
    "**/*.ets" "false" "body_state"

  gen_cursor_mdc \
    ".cursor/rules/harmonyos-build.mdc" \
    "Hvigor / OHPM / hdc / 错误码诊断 / 三种产物（hap/app/har）。改构建配置时激活。" \
    "**/oh-package.json5,**/module.json5,**/build-profile.json5,**/hvigorfile.ts" "false" "body_build"

  gen_cursor_mdc \
    ".cursor/rules/harmonyos-runtime.mdc" \
    "工程层装配陷阱：string.json 空数组、模块改名、主题切换、HUKS、Web bridge。改 module/resources 时激活。" \
    "**/module.json5,**/resources/**/*.json,**/*.ets" "false" "body_runtime"

  gen_cursor_mdc \
    ".cursor/rules/harmonyos-sign.mdc" \
    "签名三件套 + AGC 上架 + Top 20 拒因。改 AppScope/app.json5 或准备上架时激活。" \
    "**/AppScope/app.json5,**/build-profile.json5" "false" "body_sign"
}

# ─── 生成 Copilot ────────────────────────────────────────────
generate_copilot() {
  info "生成 .github/copilot-instructions.md + .github/instructions/*.md"

  # root（< 4KB 控制）
  mkdir -p .github
  local root_out=".github/copilot-instructions.md"
  {
    echo "# HarmonyOS / ArkTS / ArkUI 核心硬约束"
    echo
    echo "> GitHub Copilot 全局指令。本文件 < 4KB（code-review 安全区）；详细规则按 \`applyTo\` 自动激活，见 \`.github/instructions/\`。"
    echo
    build_core_essence
    echo
    echo "---"
    echo "> 由 \`tools/generate-ai-configs.sh\` 自动生成。**请勿手动编辑**——改源文件后重跑。"
  } > "$root_out"
  local root_size; root_size=$(wc -c < "$root_out" | tr -d ' ')
  if [[ "$root_size" -gt 4096 ]]; then
    warn "$root_out 超过 4KB（实际 ${root_size} bytes）—— 详细规则段需进一步精简"
  else
    ok "$root_out (${root_size} bytes, ≤4KB)"
  fi

  # 按场景拆的 instructions
  gen_copilot_instr \
    ".github/instructions/arkts.instructions.md" \
    "ArkTS 严格语法规则" \
    "**/*.ets,**/*.ts" "body_arkts"

  gen_copilot_instr \
    ".github/instructions/state.instructions.md" \
    "ArkUI 状态管理铁律" \
    "**/*.ets" "body_state"

  gen_copilot_instr \
    ".github/instructions/build.instructions.md" \
    "Hvigor / OHPM / hdc 构建调试" \
    "**/oh-package.json5,**/module.json5,**/build-profile.json5,**/hvigorfile.ts" "body_build"

  gen_copilot_instr \
    ".github/instructions/runtime.instructions.md" \
    "工程层装配陷阱" \
    "**/module.json5,**/resources/**/*.json" "body_runtime"

  gen_copilot_instr \
    ".github/instructions/sign-publish.instructions.md" \
    "签名与 AGC 上架" \
    "**/AppScope/app.json5,**/build-profile.json5" "body_sign"
}

# ─── 入口 ────────────────────────────────────────────────────
IFS=',' read -ra TARGET_LIST <<<"$TARGETS"
for t in "${TARGET_LIST[@]}"; do
  case "$t" in
    cursor)  generate_cursor ;;
    copilot) generate_copilot ;;
    *) warn "目标 \"$t\" 暂未支持（cursor / copilot）" ;;
  esac
done

echo
ok "完成"
info "源 → 产物："
echo "  · 5 个 SKILL.md + AGENTS.md + 内嵌硬约束精华"
echo "  →  .cursor/rules/*.mdc      ($(find .cursor/rules -name '*.mdc' 2>/dev/null | wc -l | tr -d ' ') 个)"
echo "  →  .github/copilot-instructions.md + .github/instructions/*.md"
echo
info "下一步：bash tools/doctor.sh 验证安装"
