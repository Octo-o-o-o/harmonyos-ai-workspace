# Claude Skills · HarmonyOS DevSpace

这里是为 Claude Code 准备的 Skill 集合。每个子目录是一个独立的 Skill，按需触发加载，避免一次把 600+ 行的 `CLAUDE.md` 全塞进上下文。

## 可用 Skills

| Skill | 触发条件 | 内容 |
| --- | --- | --- |
| [`arkts-rules/`](arkts-rules/SKILL.md) | 写或改 `.ets`/`.ts` 鸿蒙文件、迁移 TS 代码、`arkts-no-*` 报错 | ArkTS 严格规则、TS 反模式改写、API 验证流程 |
| [`state-management/`](state-management/SKILL.md) | 用状态装饰器、调试"UI 不刷新"、V1/V2 选型 | 替换引用铁律、V1/V2 对照、错误诊断 |
| [`build-debug/`](build-debug/SKILL.md) | 打包、Hvigor、OHPM、hdc、错误码诊断 | 三种产物、Hvigor/OHPM/hdc 命令、错误码速查 |
| [`signing-publish/`](signing-publish/SKILL.md) | 配签名、申请证书、AGC 上架、审核被拒 | `.p12`/`.cer`/`.p7b` 三件套、AGC 流程、拒因清单 |
| [`harmonyos-review/`](harmonyos-review/SKILL.md) | review 鸿蒙代码、PR 审查、上架前自查 | 9 大类 60+ 编号规则扫描，产出带优先级 markdown 报告 |

机读元数据见 [`manifest.json`](manifest.json)（Skill 列表、触发关键词、未来 fan-out 目标路径）。

## 设计原则

- **每个 Skill 独立可用**：不依赖另一个 Skill 也能完成本职任务
- **明确触发条件**：`description` frontmatter 里写清楚"什么时候该激活"，让 Claude Code 自动判断
- **链接而不是复制**：详细文档放在 `01-` ~ `09-` 主题目录，Skill 里只放最小可用的精华
- **真坑优先**：每个 Skill 第一段就抛出统计学最常见的反模式（如状态管理的"替换引用"）

## 与 root `CLAUDE.md` 的关系

`CLAUDE.md` 是项目级"大宪章"——告诉 AI 这个工作区的整体导航和硬约束。Skills 是"可分发的小卡片"——可以被抽出来单独发布成 Plugin（见 [`OPEN-SOURCE-STRATEGY.md`](../../OPEN-SOURCE-STRATEGY.md) Layer 2 部分），用在任何鸿蒙 app 项目中。

未来扩展方向：

- `arkui-component-skeleton/`：`@Entry @Component` 起手模板
- `mcp-harmonyos-setup/`：`.mcp.json` 配置与诊断
- `kit-network-http/`：`@kit.NetworkKit` 完整请求链路
- `multi-device-adapt/`：多端适配（手机/平板/折叠屏/智慧屏）
- `performance-tuning/`：Profiler 用法、首屏优化、列表虚拟化

新建 Skill 的规范见 [`OPEN-SOURCE-STRATEGY.md`](../../OPEN-SOURCE-STRATEGY.md) B.4。
