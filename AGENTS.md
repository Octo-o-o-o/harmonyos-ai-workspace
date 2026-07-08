# AGENTS.md · 跨工具通用宪法

> 本文件是**所有 AI 编码助手**（Codex / Cursor / Aider / Copilot / Claude Code / Gemini CLI / Junie / Windsurf / Zed / Warp 等 24+ 工具）的鸿蒙开发硬约束**单一真源**（[agents.md](https://agents.md/) 标准）。
>
> Claude Code 用户额外读 [`CLAUDE.md`](CLAUDE.md)（含 Skills 触发索引 + 钩子说明 + 项目导航等 Claude 特有内容；它在第 0 节明确说"通用宪法见 AGENTS.md"）。
>
> **维护者文档清单（AI 写代码不读）**：`docs/PLAN.md` / `docs/RESEARCH-*.md` / `docs/REVIEW-*.md` / `docs/OPEN-SOURCE-STRATEGY.md` / `docs/USAGE-GUIDE.md` / `docs/MCP-INTEGRATION.md` / `docs/SETUP-FROM-SCRATCH.md` / `CHANGELOG.md` / `CONTRIBUTING.md` 是给项目维护者 / 装环境的新手看的。除非用户明问"项目演进 / 贡献 / 发布 / 装 DevEco / 接 MCP"，否则忽略。

## 0. Skills 触发索引

Codex / Codex Desktop 默认读取 `.agents/skills/`，Claude Code 默认读取 `.claude/skills/`；两处各有 9 个同源 SKILL.md。手动判断索引：

| 用户场景 | skill | 内容 |
| --- | --- | --- |
| 写 / 改 `.ets` / `.ts` / TS 迁移 / `arkts-no-*` | `arkts-rules` | ArkTS 严格规则 + inline-suppress |
| 状态装饰器 / "UI 不刷新" / V1 vs V2 | `state-management` | 替换引用铁律 + V1/V2 |
| Hvigor / OHPM / hdc / 错误码 | `harmonyos-build-debug` | 命令速查 + 错误码 |
| 签名 / AGC 上架 / 审核被拒 | `harmonyos-signing-publish` | 三件套 + Top 20 拒因 |
| review 代码 / PR 审查 / 上架前自查 | `harmonyos-review` | 10 大类 75 条编号规则 |
| 主题切换 / 模块改名 / `string.json` 空数组 / HUKS 加密 / `DEVECO_SDK_HOME` / 替换品牌图标（layered icon） | `runtime-pitfalls` | 17 类工程装配陷阱（一～十七，含 NavPathStack 白屏 / emoji 渲染 / Button padding / build() 单 root / timeline timestamp / per-host store / daemon workspaceId / layered icon foreground 透明） |
| 写测试 / hypium / UiTest / `aa test` / 上架前自测·云测·性能摸底 | `testing-quality` | Local vs ohosTest 铁律 + hypium/UiTest 速查 + `aa test` CLI + 质量评估工位 |
| OpenAI Vision / Whisper / DALL-E / SSE 流式 / `string\|object[]` union | `multimodal-llm` | LLM 客户端领域 |
| ArkUI Web 组件 / `javaScriptProxy` / `runJavaScript` / Markdown 离线渲染 | `web-bridge` | H5↔ArkTS 桥 |

## 0.5 Edit 后实时校验

仓库已配 PostToolUse 钩子（仅 Claude Code 强校验；Codex 有 `.agents/skills/` 规则自动发现，但强校验仍建议用 pre-commit / CI；Cursor / Copilot 用规则文件软引导）：

- 改完 `.ets` / `.ts` / `oh-package.json5` 自动跑 `tools/hooks/lib/scan-arkts.sh` + `tools/check-ohpm-deps.sh`
- 违规打到 stderr + 写入 `.claude/.harmonyos-last-scan.txt`
- 你看到该文件存在 → **先读它**，含上次扫描的违规列表

非 Claude Code 工具用户：把这两个脚本加进 git pre-commit 或 CI 同样能保证质量。Codex 如需 MCP-HarmonyOS，显式运行 `bash tools/setup-codex-mcp.sh` 写入用户级 Codex 配置。

---

## 1. 项目环境

- HarmonyOS 6 系列：最新 Release **API 24（HarmonyOS 6.1.1，2026-05-26）**；消费推送主力 **API 23（6.1.0，2026-04-20 起）**；新项目 targetSDK 默认建议 API 23、minSDK API 12（要 API 24 新能力才上 24）
- **HarmonyOS 7 = API 26**（2026-06-12 起 Developer Beta1，官方跳过 API 25），**生产不要选**
- API 20 = 2025-09-25 仅开发者版，**不要选作 targetSDK**；API 21/22 = 历史稳定线（2025-11/2026-01）
- ArkTS + ArkUI 声明式（动态 ArkTS 是生产主线；`use static` 静态模式 ArkTS-Sta 演进中，生产不用）
- macOS 26.5 (Apple Silicon)，DevEco Studio 6.1.x（预览线 26.0.0 Beta1 起版本号切年份制、内置 Node 18 → 24）
- 命令行工具已配置 PATH：`ohpm` `hvigorw` `hdc`（ohpm 6.x 起 `view` 改名 `info`）
- 官方 AI 工具（可选）：DevEco Code / DevEco CLI（`@deveco/deveco-cli`）与本仓互补，见 `04-build-debug-tools/README.md`

## 2. 文档优先级

1. `upstream-docs/openharmony-docs/zh-cn/application-dev/`（官方权威）
2. 本目录下 `00-` 至 `09-` 主题指南
3. 网络搜索（兜底）

## 3. ArkTS 硬约束（必读）

绝不要写以下 TS 风格代码（鸿蒙编译器拒绝）：

```
any · unknown · var · /regex/ · for...in · delete · Symbol
解构赋值 · function 表达式 · #私有字段 · 索引签名
obj['key'] 动态访问 · 对象字面量无类型注解
结构性类型 · 交叉类型 · 条件类型 · 类表达式
未初始化的类字段 · 在 constructor 内声明字段
一元 + 转字符串
```

完整规则与改写：[`01-language-arkts/02-typescript-to-arkts-migration.md`](01-language-arkts/02-typescript-to-arkts-migration.md)

## 4. Import 风格

```typescript
// ✅
import { http } from '@kit.NetworkKit';
import { window } from '@kit.ArkUI';

// ⚠️
import http from '@ohos.net.http';
```

## 5. ArkUI 状态管理

不要混用 V1（`@Component @State @Prop @Link`）与 V2（`@ComponentV2 @Local @Param @Event`）。
默认用 V1，用户明确指定时切 V2。

## 6. 改完代码必跑

```bash
ohpm install
hvigorw codeLinter                               # 或 bash tools/run-linter.sh
hvigorw assembleHap -p buildMode=debug
```

`arkts-no-*` 错误：在 [`01-language-arkts/02-typescript-to-arkts-migration.md`](01-language-arkts/02-typescript-to-arkts-migration.md) 搜对应规则。

**本仓库提供轻量校验工具，可在任何 AI 工具中调用**：

```bash
# ArkTS 反模式快扫（毫秒级，30+ 规则）
bash tools/hooks/lib/scan-arkts.sh entry/src/main/ets/pages/X.ets

# OHPM 包名校验（黑名单 + 白名单 + registry 在线核验）
bash tools/check-ohpm-deps.sh entry/oh-package.json5

# 真编译期 lint（依赖 DevEco SDK，不依赖 GUI）
bash tools/run-linter.sh --strict

# 把规则同步到 Cursor / Copilot（Codex skills 由 .agents/skills 提供）
bash tools/generate-ai-configs.sh --targets=cursor,copilot
```

## 7. 不要发明 API

ArkTS / ArkUI / Kit API 在 API 12 → 24 之间多次变化。训练数据多停留在旧版，**写 API 调用前先在 `upstream-docs/.../reference/` 中验证签名**。

## 7.5 状态更新必须替换引用（LLM 第一大坑，ArkEval 数据 42%）

```typescript
// ❌ this.list.push(x); / this.user.name = 'A';        不会重渲染
// ✅ this.list = [...this.list, x];
// ✅ this.user = { ...this.user, name: 'A' };
```

V1 中嵌套对象字段要响应式：类加 `@Observed` + 引用加 `@ObjectLink`；V2：类加 `@ObservedV2` + 字段加 `@Trace`。

## 8. 文件后缀语义

- `.ets` 含 ArkUI 组件（`@Component` / `build()`）
- `.ts` 纯逻辑
- 不要把 UI 写到 `.ts`，也不要把纯逻辑写到 `.ets`

## 9. 不要引入不兼容依赖

- 不能直接 `import` npm 包；只能用 OHPM（[https://ohpm.openharmony.cn](https://ohpm.openharmony.cn)）上真实存在的包
- npm 知名库三种形态：TPC 移植版真实存在（`@ohos/axios` / `@ohos/socketio` / `@ohos/crypto-js`）；纯 JS 白名单包无前缀直用（`dayjs` / `lodash`）；多数不存在（`@ohos/dayjs` / `@ohos/uuid` 是 AI 想当然的假名）
- **包名先核验再写**（`ohpm info <pkg>` 或 OHPM 官网搜索）；首选系统 Kit（HTTP 用 `@kit.NetworkKit`），三方包是补充

## 10. 用户提需求时若没说

- 默认 ArkTS V1 装饰器系列
- 默认 Stage 模型（FA 已废弃）
- 默认 import 用 `@kit.*`
- 默认 buildMode=debug，签名用 IDE 自动签名

## 11. 调试 / 构建 / 上架命令速查

```bash
# 调试
hdc list targets
hdc -t <id> install -r entry/build/default/outputs/default/*.hap
hdc shell aa start -a EntryAbility -b com.example.x
hdc hilog | grep MyTag

# 构建
hvigorw clean
hvigorw assembleHap -p buildMode=debug
hvigorw assembleApp -p buildMode=release   # 上架包

# 依赖
ohpm install
ohpm config set registry https://ohpm.openharmony.cn/ohpm/
```

## 12. 当不确定时

直接告诉用户：「我无法验证此 API 当前形态，建议你在 DevEco 里 Ctrl+点进类型定义确认」或「在 `upstream-docs/openharmony-docs/zh-cn/application-dev/reference/` 中查询」。**不要编代码**。
