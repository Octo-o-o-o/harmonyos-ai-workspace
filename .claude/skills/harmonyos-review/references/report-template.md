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

详见 `.claude/skills/harmonyos-review/references/checklist.md`：

- `SEC-*` 安全合规 8 条
- `ARKTS-*` ArkTS 语法 14 条
- `STATE-*` 状态管理 10 条
- `LIFE-*` 生命周期 5 条
- `DB-*` 数据库 / 持久化 6 条
- `PERM-*` 权限管理 5 条
- `PERF-*` 性能 8 条
- `COMPAT-*` API 兼容 5 条
- `KIT-*` Kit 使用 7 条
