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

### v0.2.x 后续 patch（v0.3 提前实施 · 2026-05-07）

逐条评估 v0.3 候选清单后，**3 件"完全自主可控、对真实开发者立即有用"的提前做完**：

- **A · scan-arkts.sh 18 → 25 条**（高把握 grep 规则，假阳性低）：
  - `SEC-002` hilog `%{public}` 输出敏感字段（token / password / 身份证）
  - `SEC-007` 弱算法（MD5 / SHA1 / DES）
  - `DB-001` ResultSet / RdbStore 未 close
  - `KIT-002` ImageSource 解码后未 release
  - `AGC-RJ-014` UI 中文字符串硬编码（应走 `$r('app.string.xxx')`）
  - `PERF-002` 长列表用 ForEach 而非 LazyForEach
  - `STATE-006` V1 `@Link` 调用方丢 `$$`
  - 配套 fixture：`tools/hooks/test-fixtures/BadSecurityKit.ets`
  - `spec-quick-ref.md` 同步更新 ID 映射表

- **B · 4 个 Recipe 模板**（`samples/templates/`）：
  - `permission/` 完整代码：4 类常见权限（位置 / 相机 / 通知 / 麦克风）的运行时申请 + UI 解释 + 拒绝兜底
  - `list/` 完整代码：LazyForEach + IDataSource + 下拉刷新 + 上拉加载
  - `dark-mode/` 完整代码：系统主题跟随 + 资源限定符 + mediaquery 监听
  - `login/` 指引型（不写完整代码）：华为账号 SSO API 在 12 → 22 多次变化，AI 训练数据是旧版；只给"约束 + 文档链接 + 反模式提醒"避免误导

- **C · npm 薄 CLI**（`package.json` + `bin/cli.js`）：
  - 让 `npx -y github:Octo-o-o-o/harmonyos-ai-workspace` 直接可用，不必先 npm publish
  - 透传所有 `tools/install.sh` 参数（`--targets` / `--mirror` / `--uninstall`）
  - Windows 检测：明示走 WSL，不试图在 native 上跑
  - npm publish 后等价 `npx harmonyos-ai-workspace`

### v0.3 仍候选（依赖外部 / 内容工程半衰期短，等真用户反馈）

- 接入动作型 MCP 默认装（替代 docs/MCP-INTEGRATION.md 指引）—— G 半年未更新
- PowerShell 版本（Windows native）—— 多走 WSL
- Layer 2 抽出 Claude Plugin 独立仓库
- starter-kit 完整业务模板（不止 4 recipe）—— 取决于鸿蒙 API 稳定度
- SDK recipe 第三方贡献规范 —— 需先有 1-2 真实 recipe
- RAG MCP serving 13524 docs —— 独立项目级

### codex 评审响应（详见 [`docs/archive/reviews/2026-05-07-codex.md`](docs/archive/reviews/2026-05-07-codex.md)）

第三轮评审（codex 视角，源码 + WebFetch 八仓基线）。**P0 全部立即采纳**：

- **README curl 命令补全** · 三处 `curl -fsSL ...` 占位换成完整 URL，新手可直接复制
- **install.sh 补拉 OHPM 数据文件** · 加 `fetch tools/data/ohpm-{blacklist,whitelist}.txt`，避免 fresh clone 退化为内联兜底
- **`.DS_Store` 物理清理** · 删除 root / tools / tools/hooks 下的 .DS_Store（核查发现未被 git tracked，但避免 macOS 后续误 add）
- **评审归档** · `docs/REVIEW-2026-05-*.md` → `docs/archive/reviews/`（按 `日期-轮次-评审者` 命名）+ 加 README INDEX，clone 首屏不再被复盘文件淹没
- **CLAUDE.md § 14 任务模板挪到 USAGE-GUIDE.md** · 是给用户跟其他 AI 提需求时用的低频内容，不该每轮注入到 Claude 上下文
- **README 内置内容段压缩** · 13 条二级 bullet 压成 8 条精炼描述，节省 39 行

评审错判核查后澄清：
- "PLAN.md 与 docs/PLAN.md 重复" → root **没有 PLAN.md**（v1 已迁移）
- "`.cursor/rules/harmonyos.mdc` 未入库" → **已入库**（git ls-files 可见）
- "`.mcp.json` 改 npx -y" → **早已实施**（v3 第一轮）

详细处置决策见评审顶部 `## 处置决策表`。

[0.2.0]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/releases/tag/v0.2.0
[0.1.0]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/releases/tag/v0.1.0
[Unreleased]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/compare/v0.2.0...HEAD
