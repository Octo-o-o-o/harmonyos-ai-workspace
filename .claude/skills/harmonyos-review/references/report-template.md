# Code Review Report · `<scope>`

> **审查对象**：`<files / module / PR #>`
> **审查日期**：YYYY-MM-DD
> **审查者**：AI 助手 / `<reviewer-name>`
> **代码版本**：`git rev-parse HEAD` 输出
> **HarmonyOS targetSDK**：API `<n>` / minSDK API `<n>`

---

## 执行摘要

| 优先级 | 数量 |
| --- | --- |
| Critical | `<n>` |
| High | `<n>` |
| Medium | `<n>` |
| Low | `<n>` |

**整体评级：`<A | B | C | D | F>`**

> 一句话结论：`<是否阻塞上架 / 是否建议合并 / 主要风险点>`

---

## Critical Issues（必须立即修复）

### 1. `<规则 ID>` · `<简短标题>`

- **位置**：`entry/src/main/ets/pages/X.ets:42`
- **问题**：`<具体描述>`
- **影响**：`<对功能 / 安全 / 上架的影响>`
- **建议修复**：

```typescript
// ❌ 当前
<bad code snippet>

// ✅ 改写
<good code snippet>
```

- **参考**：`01-language-arkts/03-state-management-cheatsheet.md` § 5、`upstream-docs/.../xxx.md`

---

## High Issues（发版前必修）

### 1. `<规则 ID>` · `<简短标题>`

（同上格式）

---

## Medium Issues（技术债）

| 规则 ID | 文件 | 问题 | 建议 |
| --- | --- | --- | --- |
| ARKTS-012 | `entry/src/main/ets/utils/log.ets:15` | 用 `console.info` | 改用 `hilog.info(DOMAIN, 'tag', '%{public}s', msg)` |
| ARKTS-014 | `entry/src/main/ets/api/http.ts:3` | `import http from '@ohos.net.http'` | 改 `import { http } from '@kit.NetworkKit'` |

---

## Low Issues（建议优化）

（同 Medium 表格格式，可省略）

---

## 整体观察

- **代码质量**：`<亮点 / 问题模式>`
- **架构**：`<分层是否清晰、状态管理是否一致、API 调用是否封装>`
- **测试覆盖**：`<是否有 ohosTest / test 用例、覆盖率估算>`
- **文档**：`<README / 注释 / API 文档完整度>`

---

## 修复建议优先级

| Phase | 任务 | 预估工作量 |
| --- | --- | --- |
| **P0 · 立即** | `<Critical 项 1>`、`<Critical 项 2>` | 半天 |
| **P1 · 本周** | `<High 项汇总>` | 2-3 天 |
| **P2 · 下迭代** | `<Medium 项汇总>` | 视情况 |
| **P3 · 长期** | `<Low 项汇总>` | 顺手 |

---

## 复审建议

`<在 P0/P1 修完后应再做哪些校验：hvigorw codeLinter / 真机测试 / 多机型回归>`

---

## 附录 · 扫描命令记录

```bash
<列出本次审查中用过的关键 grep / hvigorw 命令，便于复现>
```

## 附录 · 引用规则编号说明

**报告必须用稳定 ID 引用规则**，不要"自由发挥写一句解释"。这是工程化壁垒——评审输出可被 grep / link / cross-reference。

### ID 命名空间总表

| 前缀 | 主题 | 数量 | 来源文件 |
| --- | --- | --- | --- |
| `ARKTS-*` | ArkTS 语法（编译期） | 14 条 | `.claude/skills/arkts-rules/references/spec-quick-ref.md` § 一 |
| `STATE-*` | 状态管理（运行时） | 10 条 | 同上 § 二 |
| `KIT-*` | Kit 使用规范 | 7 条 | 同上 § 三 + `references/checklist.md` |
| `PERF-*` | 性能反模式 | 8 条 | `references/checklist.md` § 7 |
| `SEC-*` | 安全 / 隐私 | 8 条 | `references/checklist.md` § 1 |
| `LIFE-*` | 生命周期资源管理 | 5 条 | `references/checklist.md` § 4 |
| `DB-*` | 数据库 / 持久化 | 6 条 | `references/checklist.md` § 5 |
| `PERM-*` | 权限管理 | 5 条 | `references/checklist.md` § 6 |
| `COMPAT-*` | API 兼容 | 5 条 | `references/checklist.md` § 8 |
| `AGC-RJ-*` | 上架审核拒因 | 20 条 | `07-publishing/checklist-2026-rejection-top20.md` |

合计 **88 条**带稳定 ID 的规则跨四类生命周期阶段。

### 引用格式（强制）

每条 finding 必须形如：

```
[<ID> · <Severity>] <relative-path>:<line>: <短问题>
  ↳ <修复建议（含正确写法的引用）>
  ↳ 参考：<对应 references 路径>
```

**示例**：

```
[STATE-002 · High] entry/src/main/ets/pages/Cart.ets:48:
  this.items.push(item) 不触发重渲染
  ↳ 改写：this.items = [...this.items, item]
  ↳ 参考：.claude/skills/arkts-rules/references/spec-quick-ref.md § 二

[ARKTS-014 · Medium] entry/src/main/ets/api/http.ts:3:
  import http from '@ohos.net.http' 是旧式
  ↳ 改写：import { http } from '@kit.NetworkKit'
  ↳ 参考：.claude/skills/arkts-rules/references/spec-quick-ref.md § 一 ARKTS-014

[AGC-RJ-007 · Critical] entry/src/main/ets/pages/Login.ets:15:
  hilog.info(DOMAIN, 'auth', 'token=%{public}s', token) 用 %{public} 输出 token
  ↳ 改写：用 %{private}s 或脱敏后再打
  ↳ 参考：07-publishing/checklist-2026-rejection-top20.md AGC-RJ-007
```

### 不要

- ❌ 自由文案（"这里有点问题" / "建议优化"）
- ❌ 跳过 ID 直接给修法
- ❌ 编造 ID（`SEC-099` / `STATE-100` 等）—— 必须查表

### 工具协助

- 自动扫描：`tools/hooks/lib/scan-arkts.sh --json` 直接输出带 ID 的 JSON 数组
- 跨工具集成：`tools/hooks/examples/github-action-arkts-check.yml` 在 PR 上自动评论引用 ID
