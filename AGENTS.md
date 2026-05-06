# AGENTS.md · 给 Codex / 其他 AI Agent 的指引

本文件供 OpenAI Codex CLI、Cursor、Aider 等非 Claude 类 agent 读取（约定俗成的 AGENTS.md 文件名）。Claude Code 读 [`CLAUDE.md`](CLAUDE.md)，两者内容主旨相同。

> **强烈建议先读 [`CLAUDE.md`](CLAUDE.md)**，它包含完整的项目导航、AI 硬约束、开发/调试/构建注意事项。本文件只列最紧要的跨 agent 通用规则。
>
> **维护者文档清单（AI 写代码不读）**：`PLAN.md` / `RESEARCH-NOTES.md` / `OPEN-SOURCE-STRATEGY.md` / `CHANGELOG.md` / `CONTRIBUTING.md` 是给项目维护者看的施工方案、调研、流程。除非用户明问"项目演进 / 贡献 / 发布"，否则忽略。

## 0. Skills 触发索引

`.claude/skills/` 下 5 个 SKILL.md 按 frontmatter 自动激活。手动判断索引：

| 用户场景 | skill | 内容 |
| --- | --- | --- |
| 写 / 改 `.ets` / `.ts` / TS 迁移 / `arkts-no-*` | `arkts-rules` | ArkTS 严格规则 |
| 状态装饰器 / "UI 不刷新" / V1 vs V2 | `state-management` | 替换引用铁律 + V1/V2 |
| Hvigor / OHPM / hdc / 错误码 | `harmonyos-build-debug` | 命令速查 + 错误码 |
| 签名 / AGC 上架 / 审核被拒 | `harmonyos-signing-publish` | 三件套 + Top 20 拒因 |
| review 代码 / PR 审查 / 上架前自查 | `harmonyos-review` | 9 大类 60+ 编号规则 |

## 0.5 Edit 后实时校验

仓库已配 PostToolUse 钩子（仅 Claude Code 强校验；Codex / Cursor / Copilot 用规则文件软引导）：

- 改完 `.ets` / `.ts` / `oh-package.json5` 自动跑 `tools/hooks/lib/scan-arkts.sh` + `tools/check-ohpm-deps.sh`
- 违规打到 stderr + 写入 `.claude/.harmonyos-last-scan.txt`
- 你看到该文件存在 → **先读它**，含上次扫描的违规列表

非 Claude Code 工具用户：把这两个脚本加进 git pre-commit 或 CI 同样能保证质量。

---

## 1. 项目环境

- HarmonyOS 6 系列：当前消费稳定线 **API 22（HarmonyOS 6.0.2）**，2026-01-23 起推送；**API 21（6.0.1）** 是 2025-11-25 首发版，新项目 targetSDK 默认建议 API 21、minSDK API 12
- API 20 = 2025-09-25 仅开发者版，**不要选作 targetSDK**
- ArkTS + ArkUI 声明式
- macOS 26.5 (Apple Silicon)，DevEco Studio 6.x
- 命令行工具已配置 PATH：`ohpm` `hvigorw` `hdc`

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
# ArkTS 反模式快扫（毫秒级，60+ 规则）
bash tools/hooks/lib/scan-arkts.sh entry/src/main/ets/pages/X.ets

# OHPM 包名校验（黑名单 + 白名单 + ohpm CLI）
bash tools/check-ohpm-deps.sh entry/oh-package.json5

# 真编译期 lint（依赖 DevEco SDK，不依赖 GUI）
bash tools/run-linter.sh --strict

# 把规则同步到 Cursor / Copilot
bash tools/generate-ai-configs.sh --targets=cursor,copilot
```

## 7. 不要发明 API

ArkTS / ArkUI / Kit API 在 API 12 → 22 之间多次变化。训练数据多停留在旧版，**写 API 调用前先在 `upstream-docs/.../reference/` 中验证签名**。

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

- 不能 `import` npm 包；只能用 OHPM（[https://ohpm.openharmony.cn](https://ohpm.openharmony.cn)）发布的 `.har`
- axios / lodash / moment 等 npm 名包**不存在于鸿蒙生态**，用对应 Kit 替代

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
