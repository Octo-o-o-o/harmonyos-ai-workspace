# Codex Skills · HarmonyOS DevSpace

这里是给 Codex CLI / Codex Desktop 自动发现的 HarmonyOS Skills 镜像。

## 规则来源

- `.claude/skills/` 是主源，供 Claude Code 使用。
- `.agents/skills/` 是 Codex 项目级镜像，安装目标包含 `codex` 时会一起下发。
- 两边的 `SKILL.md` 内容应保持等价；少量链接文字可以按工具入口调整。

## 可用 Skills

| Skill | 内容 |
| --- | --- |
| `arkts-rules` | ArkTS 严格语法规则、TS 反模式改写、inline-suppress |
| `state-management` | ArkUI V1 / V2 状态管理、替换引用铁律 |
| `build-debug` | Hvigor / OHPM / hdc / 错误码诊断 |
| `signing-publish` | 签名三件套、AGC 上架、审核拒因 |
| `runtime-pitfalls` | 运行时装配陷阱 |
| `harmonyos-review` | 10 大类规则审查与报告模板 |
| `multimodal-llm` | OpenAI / Anthropic / Gemini 多模态与 SSE 调用 |
| `web-bridge` | ArkUI Web 组件与 H5 ↔ ArkTS 桥 |
| `testing-quality` | hypium 单测 / UiTest / `aa test` / 云测·SmartPerf·wukong 质量工位 |

Codex 仍以 `AGENTS.md` 为跨工具硬约束入口；这里的 skills 用于按任务触发更细的上下文。
