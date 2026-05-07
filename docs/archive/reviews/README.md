# 历次评审归档

> 这里是项目演进过程中第三方评审的存档，按时间倒序。**AI 写代码不需要读这里**——核心规则已经吸收进 CLAUDE.md / AGENTS.md / SKILLs。
>
> 这些文件保留是为了**审计 trail**：未来评审者能看到"哪些建议提过、是否被采纳、为什么不采纳"，避免重复折腾。

## 时间线

| 日期 | 文件 | 评审者类型 | 关键贡献 | 处置 |
| --- | --- | --- | --- | --- |
| 2026-05-07 | LCC v0.5→v0.6 三轮反馈（CHANGELOG 内联） | PrivateTalk 真工程实测 | check-rename-module perl 跨行修复 / runtime-pitfalls §九 ❌/✅ 互换 / 装饰器上下文检测 / PERF-002 91% FPR 启发式 / 真 collapse / ARKTS-016 降级 / --stats 模式 | v0.6 全部采纳（本 commit） |
| 2026-05-07 | LCC v0.4→v0.5 二轮反馈（CHANGELOG 内联） | PrivateTalk 真工程跑 30 条规则 + check-rename | 1 真 BUG（json5 尾逗号 sed 失败） + 3 真误报（STATE-009 prefs.delete / ARKTS-003 Record 索引 / ARKTS-RECORD 空字面量）+ inline-suppress 机制 | v0.5 全部采纳 |
| 2026-05-07 | LCC v0.3 一轮反馈（CHANGELOG 内联） | PrivateTalk M3-M12 多里程碑实战 | 5 条新 ArkTS 规则 / 3 个新 SKILL（runtime-pitfalls / multimodal-llm / web-bridge）/ check-rename-module 工具 | v0.4 全部采纳 |
| 2026-05-07 | [`2026-05-07-codex.md`](2026-05-07-codex.md) | Codex 视角，基于源码 + WebFetch 八仓 | README curl 占位 / install 补拉 ohpm 数据 / 评审归档 / .DS_Store 清理 / 4 recipes 提案 / 动作 MCP 安全包装 | P0/P1 项已在 commit `d7xxx` 全部采纳 |
| 2026-05-07 | [`2026-05-07-claude.md`](2026-05-07-claude.md) | Claude 视角，基于源码 + 6+5 并行 agent 调研 | CLAUDE.md 瘦身 / ArkTS 规范库 / V2 强化 / hook timeout / AGENTS 主源 / ID 收口 / README 流程图 | 7 项已采纳（commit `c5c77a2`），3 项 v0.3 候选 |
| 2026-05-06 | [`2026-05-06-v2-claude.md`](2026-05-06-v2-claude.md) | Claude 视角，UX 流程深度对比 | scan-arkts 13→18 / OHPM 名单外置 / hook 跨工具示例 / MCP 集成指引 / bootstrap y/N / 版本契约 | 全部采纳（commit `c10df61`） |
| 2026-05-06 | [`2026-05-06-v1-claude.md`](2026-05-06-v1-claude.md) | Claude 视角，初次 8 项目对比 | 前置依赖段 / SKILL frontmatter 增强 / AGC Top 6 拒因配代码示例 / 维护者文档移 docs/ | 全部采纳（commit `f79232c`） |

## 不重复评审反复评审过的事

下面列出"每次评审都会被提一遍但已经处理"的项，方便下次评审者跳过：

- ✅ "PostToolUse 钩子是核心差异化" → README 已改为列 5 条真独占能力
- ✅ "60+ 编号"含糊表述 → README 已分层精确说明（13 自动 + 36 review + 20 AGC + 26 OHPM）
- ✅ "PLAN.md / OPEN-SOURCE-STRATEGY 在 root" → 已迁到 `docs/`
- ✅ "5 个 SKILL.md 接近 500 行上限" → 实际 84-310 行，远低于上限
- ✅ "11 工具 fan-out" → 明确不做（ROI 低）
- ✅ "16 业务模板" → 明确不做（半衰期短）

如新评审仍提这些，**指出本归档的对应行**即可。

## 仍待 v0.3 处理

- E-4 npx 入口 + 镜像默认推荐（独立工程级工作量）
- 4 个稳定 recipe（登录 / 列表 / 权限 / 深色）
- 动作型 MCP 安全包装（多天工作量）
- SDK recipe 第三方贡献规范

详见各评审文件末尾的 v0.3 候选段。
