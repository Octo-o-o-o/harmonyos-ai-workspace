# 贡献指南

欢迎 PR。本仓库的核心是**让 AI 助手准确写鸿蒙代码**——所有让 AI 写得更准、踩坑更少的内容都欢迎。

## 适合贡献什么

✅ **优先合并**：

- 真实跑过的 ArkTS / ArkUI 反模式案例（钩子 `tools/hooks/lib/scan-arkts.sh` 加规则）
- 新版 API 引入的签名变化或废弃 API（更新对应主题目录）
- AI 训练数据缺失的本土化信息（AGC 提审拒因、本地包替代物）
- `.claude/skills/<name>/SKILL.md` 新增 skill（带明确 frontmatter 触发条件）
- OHPM 包名校验数据（`tools/check-ohpm-deps.sh` 黑/白名单）
- 真实拒因案例补到 `07-publishing/checklist-2026-rejection-top20.md`

⚠️ **谨慎合并**（先开 issue 讨论）：

- 改 `CLAUDE.md` / `AGENTS.md` 的硬约束行为
- 删除现有规则
- 与现有 Skill 重叠 ≥ 60% 的新 Skill
- 影响安装 / 升级流程的脚本变化

❌ **不合并**：

- 复制官方文档大段内容（链到 `upstream-docs/...` 即可）
- 含个人路径（`/Users/...`）/ 真实 bundleName / 签名材料的提交
- 营销内容、群运营、刷 star 推广

## 提交流程

```bash
# fork & clone
git clone https://github.com/<your-fork>/harmonyos-ai-workspace.git
cd harmonyos-ai-workspace

# 拉文档镜像（按需，校对引用路径用）
bash tools/bootstrap-upstream-docs.sh

# 新分支
git checkout -b add-rule-XXX

# 改完后跑回归
bash tools/hooks/lib/scan-arkts.sh tools/hooks/test-fixtures/BadState.ets
bash tools/check-ohpm-deps.sh tools/hooks/test-fixtures/bad-oh-package.json5
bash tools/generate-ai-configs.sh --check

# 自查：无个人路径、无敏感字段、文件命名规范
git diff --stat

# commit / push / 开 PR
```

## 文件命名

- 主题目录子文件：`NN-topic-subtopic.md`（如 `01-arkts-vs-typescript.md`）
- Skill 目录：`.claude/skills/<kebab-case-name>/SKILL.md`，frontmatter 必填 `name` `description`
- 脚本：`tools/<verb-noun>.sh`（如 `verify-environment.sh`）
- 钩子规则：在 `tools/hooks/lib/scan-arkts.sh` 用稳定 ID（`STATE-002` / `ARKTS-001` / `AGC-RJ-005`）

## CLAUDE.md / AGENTS.md 改动规则

这两个文件影响 AI 行为面广：

1. 新增硬约束规则：**先开 issue，给数据支撑**（ArkEval / 真实 bug / 官方文档变化）
2. 修订版本叙述：直接 PR，但描述里给**官方权威来源**
3. 删减规则：必须给"该规则现已不适用"的证据

> 提示：CLAUDE.md 当前 ~580 行，已接近 LLM 可靠跟随的指令数上限。**新规则优先放进 `.claude/skills/`**（按需触发），CLAUDE.md 只保留全局必读。

## Skill 编写规范

```markdown
---
name: <kebab-case>
description: <一句话；写清楚"什么时候 Claude 应该激活这条 skill">
---

# 标题

> 触发场景：<一句话>

## 第一铁律 / 核心心智模型
（最常被踩的反模式 + 数据支撑）

## ...（按需）

## 进一步参考
（链回 01-/02-/.../09- 主题目录的对应文件）
```

要求：

- **触发条件具体**：写"用户在 `.ets` 文件中使用状态装饰器并问 'UI 不刷新'"，不要写"状态相关问题"
- **链接而不是复制**：详细参考留在主题目录，Skill 只放精华
- **真坑优先**：第一段就抛最常见的反模式
- **行数 < 200**：超过就拆

## upstream-docs 不接受 PR

`upstream-docs/openharmony-docs/` 是 OpenHarmony 官方仓库镜像（CC-BY-4.0）。任何针对该目录的 PR 不会被合并。如发现官方文档错误，请到 [openharmony/docs Gitee](https://gitee.com/openharmony/docs) 提 PR。

## 致谢

ArkTS 严格规则部分参考了：

- 官方迁移指南：<https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/typescript-to-arkts-migration-guide>
- ArkEval 基准（arxiv 2602.08866）的错误分布数据
- 社区 [`aresbit/arkts-dev-skill`](https://github.com/aresbit/arkts-dev-skill)
- 同类项目调研沉淀在 [`PLAN.md`](docs/PLAN.md) § 五
