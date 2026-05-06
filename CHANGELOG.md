# Changelog

遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) + [SemVer](https://semver.org/lang/zh-CN/)。版本节奏跟随 HarmonyOS 大版本。

## [0.2.0] - 2026-05-06

完整施工方案与决策记录见 [`PLAN.md`](docs/PLAN.md)。本版完成 P0+P1 全套：

- **PostToolUse 钩子** · Claude Code 每次 Edit/Write 自动跑 ArkTS 反模式扫描 + OHPM 包名校验，结果回喂 AI 上下文
- **`tools/install.sh`** · curl-pipeable 一行装到任意鸿蒙 app（默认 Claude Code + Codex；可加 Cursor / Copilot）
- **`tools/check-ohpm-deps.sh`** · 黑/白名单 + ohpm CLI 三层 OHPM 包名校验
- **`tools/run-linter.sh`** · 离线 hvigorw codeLinter wrapper（不依赖 DevEco GUI）
- **`tools/generate-ai-configs.sh`** · 真单源 fan-out：`.claude/skills/*/SKILL.md` → `.cursor/rules/harmonyos.mdc` + `.github/copilot-instructions.md`
- **`07-publishing/checklist-2026-rejection-top20.md`** · 提审 Top 20 拒因（带稳定 ID `AGC-RJ-001…020`）
- **`tools/hooks/test-fixtures/`** · 钩子回归 fixture
- **`.claude/skills/harmonyos-review/`** · 代码审查 skill + 60+ 编号规则 + 报告模板

## [0.1.0] - 2026-05-06

仓库雏形：

- 10 个主题目录（`00-getting-started/` ~ `09-quick-reference/`）+ `CLAUDE.md` + `AGENTS.md`
- 4 个 `.claude/skills/`（arkts-rules / state-management / build-debug / signing-publish）
- 5300+ 篇 OpenHarmony 官方文档镜像（用 `tools/bootstrap-upstream-docs.sh` 拉取）
- `.mcp.json` 接通 mcp-harmonyos
- LICENSE / CONTRIBUTING / .gitignore / GitHub Actions markdown lint
- 版本叙述校正（API 21 = 2025-11-25 首发 / API 22 = 2026-01-23 推送）
- ArkEval 数据驱动：「数组就地 mutation」提到 CLAUDE.md § 0.5 最高优先级

## [Unreleased]

- v0.3 候选（按反馈定）：扩展规则到 60+ 编号 ID 一致 / Layer 2 抽 Claude Plugin / 写侧 MCP / starter-kit 业务模板

[0.2.0]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/releases/tag/v0.2.0
[0.1.0]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/releases/tag/v0.1.0
[Unreleased]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/compare/v0.2.0...HEAD
