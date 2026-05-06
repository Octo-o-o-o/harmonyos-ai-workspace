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

### v0.2.x post-review patches

- **v2 评审响应**（详见 [`docs/REVIEW-2026-05-06-v2.md`](docs/REVIEW-2026-05-06-v2.md)）：
  - `scan-arkts.sh` 13 → 18 条规则（+ KIT-001 / PERF-001 / ARKTS-016 / STATE-009 / SEC-001 / COMPAT-001）+ `--json` 输出模式
  - OHPM 黑/白名单拆到 `tools/data/ohpm-{blacklist,whitelist}.txt`（26+22 项）
  - `tools/hooks/examples/` 跨工具 hook 接入示例（Codex/Cursor pre-commit / Copilot 占位 / GitHub Action CI）
  - `docs/MCP-INTEGRATION.md` 接入第二个 MCP server（动作型，hdc 控设备）的指引
  - `tools/bootstrap-upstream-docs.sh` 加交互式 y/N 提示（默认不拉 2.7 GB）
  - README "核心差异化"重写为 5 条真独占能力 + 4 层规则编号体系精确说明
- **新手向导**：
  - `tools/setup-from-scratch.sh` 半自动主入口（基础工具→DevEco 引导→PATH→Claude Code→装规则→钩子自测）
  - `docs/SETUP-FROM-SCRATCH.md` 详细引导文档（macOS 干净到 hello world，30-60 分钟）
  - `verify-environment.sh` 每个失败项给"下一步建议"，OpenHarmony 文档镜像降为可选
  - `install.sh` 装完检测 Claude Code / DevEco 缺失并提示
- **v3 评审响应**（详见 [`docs/REVIEW-2026-05-07.md`](docs/REVIEW-2026-05-07.md)）：
  - **第一轮**（B-fix + C-3）：
    - `post-edit.sh` 退出码语义修正：High → exit 2（block + 反馈给 AI），Medium → exit 0（让 AI 看见但不阻塞），消除"Medium 级 exit 1 让 Claude 看不到反馈"的隐性 bug
    - `.mcp.json` 改 `npx -y mcp-harmonyos@latest`：fresh clone 不再需要先全局装 npm 包
    - **版本契约**：README 顶部加 yaml `targets:` 段；5 个 SKILL.md frontmatter 加 `verified_against: harmonyos-6.0.2-api22`
  - **第二轮**（G-1 / C-1 / C-2 / C-4 / E-1 / E-2 / X-2 全部采纳）：
    - **G-1 CLAUDE.md 瘦身**：650 → 484 行；§ 11-13 详细内容（150 行）拆到新建的 `.claude/skills/build-debug/references/develop-debug-build.md`，CLAUDE.md 保留高频精华
    - **C-1 ArkTS 规范快查**：新建 `.claude/skills/arkts-rules/references/spec-quick-ref.md`：14 ARKTS / 6 STATE / 4 KIT/PERF/SEC/COMPAT 条规则映射到官方规范条款 + 正确写法表；arkts-rules SKILL.md 顶部强调"必须引用 ID 而非凭印象"
    - **C-2 state-management V2 强化**：SKILL.md 加 6 个完整 V2 范例（覆盖 11 装饰器）+ V1→V2 决策树 + 5 条 V2 反模式
    - **C-4 钩子 timeout**：post-edit.sh 加 `timeout 10`（gtimeout fallback），超时返回 124 → 不阻塞 AI 流程
    - **E-1 AGENTS.md 重定位为通用宪法**：标 [agents.md 标准](https://agents.md/) 24+ 工具兼容；CLAUDE.md 顶部加"通用宪法见 AGENTS.md"，冲突以 AGENTS.md 为准
    - **E-2 ID 体系收口**：harmonyos-review report-template 强制要求所有 finding 用稳定 ID 引用；列出 9 大命名空间 88 条规则 + 引用格式示例
    - **X-2 README 一图流**：加 ASCII art 流程图：AI 启动 → 钩子触发 → stderr 反馈 → AI 自我修正

### v0.3 候选（按真实用户反馈定）

- 扩展自动扫描到稳定 36 ID 规则集
- Layer 2 抽出 Claude Plugin 独立仓库
- PowerShell 版本（Windows native 用户）
- 接入动作型 MCP 写侧能力（默认装而非指引）
- starter-kit 业务模板（取决于鸿蒙 API 稳定度）

[0.2.0]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/releases/tag/v0.2.0
[0.1.0]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/releases/tag/v0.1.0
[Unreleased]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/compare/v0.2.0...HEAD
