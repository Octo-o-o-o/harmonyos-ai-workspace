# 下一步建议与取舍复审 · 2026-05

> 本文基于 [`RESEARCH-AI-HARMONYOS-USER-PAINPOINTS-2026-05.md`](RESEARCH-AI-HARMONYOS-USER-PAINPOINTS-2026-05.md) 和 2026-05-09 外部调研，给出下一步行动建议，并专门标注：哪些是最优解、哪些无法真正解决、哪些属于过度设计。
>
> 本文是维护者路线图，不是 AI 日常写代码的规则入口。

## 判断标准

下一步不按“功能数量”排序，而按四个标准排序：

1. **信任优先**：用户必须能知道工具是否真的安装、生效、可卸载、可复现。
2. **短路径优先**：vibe coding 用户需要“一条命令验收”和“一个 prompt 开始改功能”，不是读 20 页文档。
3. **工具机制优先**：Claude、Codex、Cursor、Copilot 的规则加载机制不同，不能用同一个大 Markdown 解决所有问题。
4. **边界清晰优先**：能用 scanner 拦的就拦，必须靠 hvigorw/DevEco/AGC/真机确认的就明说，不伪装成自动化。

## 更新后的最优方案

最优方向不是做一个“大而全的鸿蒙 AI IDE”，而是做一个 **HarmonyOS AI Guardrail Kit**：

- 第一层：安装、doctor、卸载、升级，保证用户信任。
- 第二层：短规则入口，保证 AI 不犯最高频错误。
- 第三层：按场景加载的 skills / instructions，避免上下文噪音。
- 第四层：hook / pre-commit / CI，给无 hook 工具补强。
- 第五层：只读审计报告和迁移计划，帮助老项目和跨平台迁移，但不承诺一键重写。

## P0：必须先做

### 1. 修正多工具 fan-out 设计

**问题**：当前 README 承诺 8 个 skill fan-out，但生成器实际只拼 5 个；Cursor/Copilot 单文件也过大。

**建议**：

- `.github/copilot-instructions.md` 控制在 4KB 内，只放核心硬约束。
- 新增 `.github/instructions/*.instructions.md`：
  - `arkts.instructions.md`
  - `state.instructions.md`
  - `runtime.instructions.md`
  - `web.instructions.md`
  - `llm.instructions.md`
  - `review.instructions.md`
- 新增多个 `.cursor/rules/*.mdc`，按 globs 和 description 触发。
- README 改为“8 个 skill 中核心 5 个默认 fan-out，专项 3 个按场景 fan-out”，或者真正生成 8 个。

**验收标准**：

- `bash tools/generate-ai-configs.sh` 生成多文件。
- `bash tools/generate-ai-configs.sh --check` 检查源和目标都同步。
- `wc -c .github/copilot-instructions.md` 小于 4000。
- README、CLAUDE、llms 对 fan-out 数量表述一致。

**不要做**：把所有 skill 继续塞进一个 always-on 文件。

### 2. 单一版本契约

> **状态更新（2026-07-09）**：全仓版本叙述已在 v0.5.0 统一为 API 24 Release / API 23 消费主力 / API 26 Beta（见 `docs/RESEARCH-UPDATE-2026-07.cursor.fable.md`）。`platform-matrix.json` 单源生成仍是候选项，未实施。

**问题**：生成器仍写 `6.1 dev beta`，但其他文档已改 API 23 Developer Beta。

**建议**：

- 新增 `tools/data/platform-matrix.json` 或 `docs/platform-matrix.json`。
- 字段包含：
  - `min_supported_api`
  - `recommended_target_api`
  - `current_consumer_stable_api`
  - `developer_preview_api`
  - `last_verified_docs_snapshot`
  - `source_urls`
- README、AGENTS、CLAUDE、llms、Cursor、Copilot 均从该文件生成版本段。

**验收标准**：

- `rg "6\\.1 dev beta"` 全仓无命中。
- `rg "API 23"` 命中都指向 developer preview / beta，不误写成生产 target。
- 发版前只改一个版本源。

**不要做**：人工维护 6 份版本说明。

### 3. `doctor` 命令

**问题**：用户能装上文件，但不知道规则、hook、MCP、DevEco 工具链是否真能工作。

**建议**：

新增：

```bash
npx -y harmonyos-ai-workspace doctor
```

检查：

- 当前目录是否像 HarmonyOS app：`AppScope/app.json5`、`entry/src/main/module.json5`。
- `CLAUDE.md` / `AGENTS.md` 是否存在，是否被本工具 manifest 管理。
- `.claude/settings.json` hook 命令是否可执行。
- `tools/hooks/post-edit.sh` 自测是否能抓 `STATE-002`。
- `hvigorw`、`ohpm`、`hdc` 是否在 PATH。
- `.mcp.json` 是否存在，MCP 包是否 pin 版本。
- Cursor/Copilot 规则文件是否存在，大小是否超出建议。

**验收标准**：

- `doctor` 输出 PASS/WARN/FAIL 三态。
- FAIL 给下一步命令，不只报错。
- CI 加 doctor fixture，避免安装器改坏。

**不要做**：doctor 自动修所有问题。自动修应另设 `doctor --fix`，且只修低风险项。

### 4. npm 包内容与 README 链接一致

**问题**：README 链接 `docs/USER-GUIDE.md` 和 `samples/templates`，但 npm pack 不包含这些目录。

**建议**：

- 把 `docs/USER-GUIDE.md`、`samples/templates/README.md`、核心 samples 纳入 `package.json.files`。
- 或 README 对 npm 用户统一链接 GitHub 绝对 URL。

**验收标准**：

- `npm pack --dry-run` 能看到 README 中本地相对链接指向的关键文件。
- markdown link check 不报这些链接。

**不要做**：把 `upstream-docs` 打进 npm 包。

## P1：高价值增强

### 5. `legacy-audit`：老鸿蒙项目只读审计

**问题**：老项目维护者需要先知道风险在哪里，而不是马上让 AI 改代码。

**建议**：

新增脚本和 skill：

```bash
bash tools/audit-harmonyos-project.sh --output harmonyos-audit.md
```

报告内容：

- API level、target/min、Stage/FA 迹象。
- `@ohos.*` import、deprecated API、V1/V2 混用。
- `build-profile.json5` / `module.json5` / `oh-package.json5` 名称一致性。
- 资源硬编码、权限最小化、Web 安全、HUKS/敏感日志。
- 建议按 P0/P1/P2 排序，每项给最小修复 prompt。

**验收标准**：

- 对一个 sample bad project 输出稳定 Markdown。
- 默认只读，不修改工程。

**不能真正解决**：

- 它不能判断业务逻辑是否正确。
- 它不能证明所有 API 签名在当前 SDK 可用。

### 6. `migration-assistant`：迁移规划而非一键迁移

**问题**：Android/iOS/Web/uni-app 用户需要迁移路线，但一键转换不现实。

**建议**：

新增 skill，输入可以是目录、文件片段或用户描述，输出：

- 页面清单。
- SDK/权限/存储/网络/WebView/推送/支付/登录清单。
- Android/iOS/Web 概念到 HarmonyOS 替换矩阵。
- 分阶段计划：UI、数据层、系统能力、真机验证、上架材料。
- 每阶段的 AI prompt 模板。

**验收标准**：

- 至少覆盖 Android 常见栈：XML/RecyclerView/Activity/Fragment/Room/Retrofit/SharedPreferences/WebView。
- 明确标注三方 SDK 需要供应商确认。

**不要做**：

- 不做“一键 Android project to HarmonyOS project”。
- 不自动批量重写用户工程。

### 7. Starter feature pack

**问题**：新用户有片段，但缺“复制后能跑”的功能包。

**建议**：

每个 recipe 目录增加：

- `README.md`
- `*.ets`
- `module.json5.patch.md`
- `string.json.patch.md`
- `verify.sh` 或验证命令
- `expected-output.md`

优先顺序：

1. privacy-consent
2. permission
3. navigation-tab
4. list-refresh-loadmore
5. settings-dark-mode
6. network-client
7. secure-preferences-huks
8. web-bridge
9. llm-sse-client

**验收标准**：

- 每个 feature 能被 scanner 扫过。
- 每个 feature 明确 verified API。
- UI 文案走资源，不靠 scanner 漏检。

**不要做**：完整业务 app 模板。业务模板半衰期短，维护成本高。

### 8. i18n / UI 文案扫描增强

**问题**：当前 `AGC-RJ-014` 漏模板字符串、`promptAction.showDialog`、按钮、Toast 等。

**建议**：

- 增加 UI 入口识别：`Text`、`Button`、`promptAction.showDialog`、`showToast`、`AlertDialog`。
- 对示例里确需中文的地方提供资源文件，而不是加 ignore。
- 对变量拼接只给 Medium 提醒，避免误报过高。

**验收标准**：

- 新增 bad fixture 覆盖 `Text(\`中文\`)` 和 `showDialog({ title: '权限申请' })`。
- samples 清扫仍为 0。

## P2：谨慎推进

### 9. AST / tree-sitter 严格扫描

**价值**：能降低 grep 假阳/漏报，尤其是状态装饰器、UI 文案、对象字面量、try/await。

**风险**：引入 Node/Python 依赖、安装成本和维护成本。

**建议**：

- hook 仍用 shell 快扫。
- CI 或 `doctor --strict` 才启用 AST 扫描。
- 只覆盖当前 grep 明显不足的规则，不重写全部 scanner。

**不建议现在做**：把 AST scanner 作为默认 PostToolUse hook。

### 10. MCP 深集成

**价值**：查询设备、项目、构建产物对 vibe coding 很有用。

**风险**：MCP 包 `latest` 漂移，动作型工具可能误装/误删/误启动。

**建议**：

- 默认 pin `mcp-harmonyos` 已验证版本。
- README 写清它是“查询型 MCP”，build/deploy 仍走 Bash 显式命令。
- 动作型 hdc MCP 只做可选，不默认装。

**不建议现在做**：默认让 AI 自动安装 HAP、启动 app、清数据。

### 11. API 文档 RAG / 官方索引

**价值**：API drift 是核心痛点。

**风险**：2.7GB docs 镜像重，构建索引复杂，容易变成搜索系统项目。

**建议**：

- 先做轻量 `docs/api-index.md`：按主题列官方路径和关键词。
- 后续再考虑本地索引，不作为 P0。

**不建议现在做**：维护自己的完整 API 摘要库。

## P3：暂缓或不做

| 想法 | 判断 | 原因 |
| --- | --- | --- |
| 一键 Android/iOS 自动迁移 | 暂缓 | 超出 guardrail 定位，错误代价高 |
| 完整 DevEco 替代 CLI | 不做 | DevEco/SDK/签名/模拟器生态不可替代 |
| 自动提交 AGC 审核材料 | 不做 | 合规和账号风险高 |
| 自动修复所有 scanner 命中 | 暂缓 | 很多命中需要业务判断 |
| 内置第三方 SDK 全量 cookbook | 不做 | 半衰期短，供应商变化快 |
| 默认安装动作型 hdc MCP | 暂缓 | 风险高，适合用户显式启用 |

## 需要同步修正的已知问题

这些不是新功能，但应随下一版修掉：

- 全仓统一 `EncryptedPreferences` 表述；无法验证时改为 HUKS / Universal Keystore Kit / 关键资产存储服务。
- `.mcp.json` 从 `@latest` 改为已验证版本或 major range。
- README 中“8 个 SKILL fan-out”改成真实机制。
- `generate-ai-configs.sh` 的版本事实从单一版本源生成。
- `samples/templates` 的 UI 文案资源化，避免 scanner clean 但样例仍不合规。
- `docs/USAGE-GUIDE.md` 竞品矩阵更新为 2026-05 新调研结果，并标 `checked_at`。

## 两周内建议执行顺序

### 第 1 批：信任与一致性

1. 加 `platform-matrix.json`，重生成版本段。
2. 改 `generate-ai-configs.sh` 为多文件输出。
3. 控制 Copilot root instructions 小于 4KB。
4. 修 README 与 fan-out 真实行为不一致。
5. 修 npm 包缺 docs/samples 的问题。

### 第 2 批：可验收体验

1. 加 `doctor`。
2. doctor 纳入 `npm test`。
3. 加 i18n bad fixtures。
4. 修 samples 文案资源化。
5. pin MCP 版本。

### 第 3 批：扩展场景

1. 加 `legacy-audit` 只读报告。
2. 加 `migration-assistant` skill。
3. 把 starter feature pack 从 2 个高频功能开始做，不一次做完 9 个。

## 成功指标

- 新用户 5 分钟内能证明 hook 工作。
- Cursor/Copilot 用户能在对应文件触发专项规则，而不是读一个 29KB 大文件。
- 老项目用户能得到一份只读风险报告。
- 迁移用户能得到阶段计划和替换矩阵，而不是被承诺一键迁移。
- 所有“无法自动证明”的事项都在文档中明确写出人工确认边界。

## 最终取舍

当前最优解是：**继续做规则与验证基础设施，不要做完整迁移器；继续做 starter feature，不要做完整业务模板；继续增强多工具输出，不要把所有工具当成 Claude Code。**

这条路线能保住本仓库的差异化：它不是又一个鸿蒙教程，也不是又一个 Claude skill 集合，而是把 AI 写鸿蒙代码这件事变得可验证、可复现、可逐步交付。
