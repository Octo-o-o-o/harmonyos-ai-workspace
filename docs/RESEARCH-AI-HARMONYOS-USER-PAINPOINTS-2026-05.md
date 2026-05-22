# AI 辅助鸿蒙开发用户痛点与方案映射 · 2026-05

> 本文沉淀 2026-05-09 复审结论：新开发、老鸿蒙维护、其他平台迁移三类用户在使用 Claude Code / Codex / Cursor / Copilot 开发 HarmonyOS app 时的真实痛点，以及本仓库当前覆盖度、可改进方式、不可真正解决的边界。
>
> 本文是维护者研究文档，不是给 AI 日常写代码时预加载的规则。

## 结论摘要

本仓库当前最强的定位是：**把通用 AI 编码助手变成“不容易写出 ArkTS 编译错误”的鸿蒙开发协作者**。它已经覆盖 ArkTS 严格语法、状态更新、OHPM 假包、构建调试、权限/上架拒因、Web/LLM 特定坑。真正的下一步不是继续堆规则，而是把规则变成更短、更可靠的用户工作流。

优先级最高的用户价值有三类：

1. 新开发：从空工程到可运行 MVP 的最短路径，避免 ArkTS、状态、依赖、权限、上架基础坑。
2. 老鸿蒙维护：扫出现有工程的 API drift、装饰器混用、旧 import、模块配置错位、资源/权限隐患。
3. 其他平台迁移：不要承诺一键迁移，而是输出盘点报告、替换矩阵、分阶段计划和关键代码模板。

## 调研依据

外部资料显示，ArkTS 仍是低资源语言。ArkEval 2026-02 论文基于 400+ 官方 ArkTS 应用挖掘出 502 个可复现问题，用来评估 LLM 修复能力；ArkTS-CodeSearch 也强调 ArkTS 代码智能缺少公开数据和基准。社区文章的共识是：AI 能快速生成 ArkUI 布局和重复代码，但在 ArkTS 受限语法、状态管理、权限、生命周期、系统 API、迁移细节上容易出错。

官方 HarmonyOS 知识地图把开发旅程拆成准备学习、体验设计、应用架构、质量、开发工具、功能开发、测试、上架分发；这说明真实用户的困难不只是“语法怎么写”，还包括工程配置、真机调试、质量测试、签名发布、跨设备能力、隐私安全。

近 5 个月内仍活跃的相邻项目给出的信号：

| 项目 | 最近确认更新 | 可借鉴点 |
| --- | --- | --- |
| `yibaiba/harmonyos-skills-pack` | 2026-04-03 | starter-kit、Day-by-Day 执行顺序、产品质量检查 |
| `FadingLight9291117/arkts_skills` | 2026-02-11 | skill + assets + references 的轻量分层 |
| `aresbit/arkts-dev-skill` | 2026-03-31 | ArkTS 规范资料包 |
| `FadingLight9291117/mcp-harmonyos` | 2026-02-16 | 设备/项目/构建产物查询型 MCP |
| `ohosvscode/arkTS` | 2026-05-03 | schema、补全、project detector、codelinter 级 IDE 体验 |
| `howells/arc` | 2026-05-04 | 显式 workflow 入口、运行时安装、跨工具 skill 暴露 |
| `op7418/Claude-to-IM-skill` | 2026-03-24 | setup / doctor / update / verify 的用户体验 |

## 场景一：新开发 HarmonyOS App

### 用户真实痛点

- 不熟 ArkTS，按 TypeScript 习惯写 `any`、解构、对象字面量、索引访问、`delete`、`for...in`，编译器直接拒绝。
- AI 生成页面看起来对，但状态不刷新，例如 `this.list.push(x)`、嵌套对象字段就地改。
- AI 瞎编 npm/OHPM 包，或者把 Web/Node 生态的 axios/lodash/openai-sdk 带进鸿蒙工程。
- API 版本变化快，训练数据常停在旧 `@ohos.*`、旧 picker、旧 Account/Ability 写法。
- 不知道最小可发布 app 还需要隐私弹窗、权限说明、深色模式、异常兜底、资源国际化。
- 构建失败后只会把错误描述给 AI，AI 继续猜。

### 当前覆盖度

覆盖强：

- `AGENTS.md` / `CLAUDE.md` / skills 给出 ArkTS 硬约束、状态铁律、import 规则、构建命令。
- `scan-arkts.sh` 能在 Edit 后抓 31 条高频反模式。
- `check-ohpm-deps.sh` 能拦截伪包并区分 FAKE / NET / UNKNOWN。
- `samples/templates/permission`、`list`、`dark-mode`、`login` 覆盖常见 starter 片段。
- `docs/USER-GUIDE.md` 已有首次验收和典型 prompt。

覆盖不足：

- 片段不是完整 feature pack。用户仍要自己把 `.ets`、`module.json5`、`string.json`、路由、资源文件拼起来。
- Cursor/Copilot 的规则生效弱于 Claude Code，且单文件规则过大，重要专项可能不触发。
- scanner 不能代替 hvigorw/codeLinter，对 API 签名、类型推导、组件合法性仍无能为力。

### 更合适的解决方式

- 提供 `starter-feature` 套件，而不是完整 app 脚手架：每个功能目录包含 `README.md`、`.ets`、`module.json5.patch`、`string.json.patch`、验证命令和预期输出。
- 做 `doctor` 命令：检查 DevEco、`hvigorw`、`ohpm`、`hdc`、Claude hook、MCP、Cursor/Copilot 规则文件和 npm 包内容。
- 把 Cursor/Copilot 从单大文件改成多规则文件：core、arkts、state、runtime、web、llm、review。
- 保持 hook 快速启发式，CI 再跑严格检查；不要把所有语义判断塞进 shell scanner。

### 值得覆盖吗

值得，而且应继续作为第一优先级。新开发用户最容易被“一行安装 + 5 分钟看到 hook 抓错”转化。

## 场景二：老 HarmonyOS App 维护

### 用户真实痛点

- 老项目跨 API 9/10/12/14/18/21/22，混有旧 `@ohos.*`、旧 Ability/Stage 写法、旧组件 API。
- 项目有历史技术债，AI 修改局部时容易引入 V1/V2 混用、状态策略漂移、模块依赖错位。
- 多 module 工程里 `build-profile.json5`、`module.json5`、`oh-package.json5` 名称不一致，错误信息不直观。
- 维护者不想让 AI “重写整个文件”，只想要最小 diff。
- 上架或兼容性问题来自资源、权限、深色模式、隐私、安全日志，编译不一定能暴露。

### 当前覆盖度

覆盖中等偏强：

- `runtime-pitfalls` 覆盖模块重命名、string.json 空数组、Web bridge 稳定实例、HUKS、OHPM 502。
- `check-rename-module.sh` 已解决模块名一致性。
- `harmonyos-review` 和 `07-publishing` 提供 review / 上架拒因 ID。
- `AGENTS.md` 已要求默认延续现有装饰器风格，不混用。

覆盖不足：

- 没有“旧工程审计报告”入口，用户不能一键得到：API level、Stage/FA、V1/V2、旧 import、废弃 API、资源硬编码、权限最小化、构建产物状态。
- 缺少 API 版本差异矩阵和升级路径，例如 API 12 到 21/22 哪些写法需要迁。
- 对历史业务约束、团队架构规则没有采集机制，AI 仍可能按通用模板改坏工程。

### 更合适的解决方式

- 新增 `legacy-audit` skill 和脚本：只读扫描工程，输出 Markdown 报告，不自动改。
- 报告按风险排序：P0 编译必炸、P1 运行/状态风险、P2 上架/质量风险、P3 风格建议。
- 对每条建议给“最小 diff 策略”和“不要重写整个文件”的 prompt。
- 支持用户把报告贴给 Claude/Codex 后逐项修复。

### 值得覆盖吗

值得。它和新开发用户不同，但更接近真实商业项目。实现时应先做只读审计，避免自动迁移带来信任问题。

## 场景三：Android / iOS / Web / Flutter / uni-app 等迁移

### 用户真实痛点

- Android XML / RecyclerView / Fragment / Activity / Room / Retrofit / SharedPreferences / WebView 无法直接搬到 ArkUI/ArkTS。
- 三方 SDK 缺鸿蒙版本，或者包名、权限、签名、AGC 配置全变。
- UI 范式从命令式/XML 到 ArkUI 声明式，页面结构、状态流、生命周期都要重构。
- Web/H5 保留时要重写 JS bridge，`javaScriptProxy`、权限、安全设置和调试链路不同。
- uni-app x /跨端方案也不是“零成本”，仍需要本地 DevEco、签名、权限、真机验证、路径长度和模拟器限制。
- 迁移经理关心阶段计划和风险，开发者关心具体替换代码。

### 当前覆盖度

覆盖较弱：

- 有 TS 到 ArkTS 迁移规则、Web bridge skill、LLM app case study。
- 没有 Android/iOS/Flutter/uni-app 的迁移盘点模板。
- 没有“功能/SDK/权限/数据/页面”替换矩阵。
- 没有 UI 迁移的组件映射表，例如 RecyclerView 到 LazyForEach、XML layout 到 Column/Row/Grid、SharedPreferences 到 Preferences/HUKS。

### 更合适的解决方式

新增 `migration-assistant`，但定位必须克制：

1. 第一步只做盘点：输入项目目录/代码片段，输出模块、页面、SDK、权限、存储、网络、WebView、推送、支付、登录清单。
2. 第二步给替换矩阵：Android/iOS/Web 概念到 HarmonyOS 概念，不直接承诺生成完整可运行工程。
3. 第三步按页面/模块逐个迁：每次生成一个页面或一个数据层 adapter，并要求跑 scanner + codeLinter。
4. 第四步保留人工确认：三方 SDK、支付、地图、登录、推送、受限权限必须查供应商和 AGC。

### 值得覆盖吗

值得覆盖“迁移规划”和“迁移模板”，不值得承诺“一键转换”。UITrans 这类研究可以作为方向参考，但本仓库当前更适合做 AI workflow guardrail，不适合变成完整自动迁移器。

## 场景四：团队 Lead / 多 AI 工具协作

### 用户真实痛点

- Claude、Codex、Cursor、Copilot 吃到的规则不同，同一项目生成风格不一致。
- Cursor/Copilot 没有 Claude Code 那样的 PostToolUse 强校验，只靠软规则。
- 规则文件太长，模型忽略或上下文被截断。
- PR review 和本地 chat 使用的指令机制不同。
- 团队想知道“规则是否真的生效”，而不是只看到文件存在。

### 当前覆盖度

覆盖中等：

- 有 `AGENTS.md`、`CLAUDE.md`、`.cursor/rules/harmonyos.mdc`、`.github/copilot-instructions.md`。
- 有 `generate-ai-configs.sh` 做 fan-out。
- 有 pre-commit 和 GitHub Actions 示例。

覆盖不足：

- README 说 8 个 skill fan-out，但生成器实际只拼 5 个核心 skill。
- Copilot 单文件约 29 KB，code review 场景会截断前 4000 字符后的内容。
- Cursor 只有一个大规则文件，不能按 `.ets`、`module.json5`、Web、LLM、上架 review 精准触发。

### 更合适的解决方式

- 生成多个目标文件：
  - `.cursor/rules/harmonyos-core.mdc`
  - `.cursor/rules/harmonyos-arkts.mdc`
  - `.cursor/rules/harmonyos-web.mdc`
  - `.cursor/rules/harmonyos-llm.mdc`
  - `.github/instructions/arkts.instructions.md`
  - `.github/instructions/harmonyos-web.instructions.md`
  - `.github/instructions/harmonyos-review.instructions.md`
- `.github/copilot-instructions.md` 保持 4KB 内，只放不可违反的核心规则和“按路径读取 instructions”的引导。
- `doctor` 输出每个工具的规则状态和已知限制。

### 值得覆盖吗

值得。多工具一致性是本仓库差异化之一，但必须尊重各工具机制，不要用一个巨型 Markdown 假装全都能读完。

## 场景五：LLM / Web / 多媒体类鸿蒙 App

### 用户真实痛点

- OpenAI/Claude/Gemini payload 常用 union 类型，ArkTS 不支持。
- SSE 流式解析、半包 buffer、`requestInStream`、`destroy()` 都容易被 AI 漏掉。
- multipart 上传、base64 文件保存、fd close、敏感 key 加密、安全日志都是运行期/上架坑。
- Markdown/HTML 渲染常要 Web 组件，JS bridge 和安全设置容易错。

### 当前覆盖度

覆盖较强：

- `multimodal-llm` 覆盖 union content、SSE、multipart、DALL-E/base64、API key、错误处理。
- `web-bridge` 覆盖 `javaScriptProxy` 稳定实例、`runJavaScript` 时序、Web 安全设置、调试。
- `runtime-pitfalls` 包含 HUKS、Web bridge、OHPM 502。

覆盖不足：

- 这些专项 skill 没有 fan-out 给 Cursor/Copilot。
- 没有最小可运行 LLM client sample，只在 case study 和 skill 中描述。
- 对 OpenAI/Claude/Gemini 最新 API 不应硬编码，容易过时。

### 更合适的解决方式

- 做“协议无关”的 LLM client recipe：只给 ArkTS 网络/SSE/文件/密钥骨架，具体云 API 字段要求用户查官方。
- 对 Cursor/Copilot 生成 `llm.instructions.md` / `web.mdc`。
- 保持 case study，不把第三方 API SDK 化。

### 值得覆盖吗

值得，但要守住边界：解决 ArkTS/HarmonyOS 端通用坑，不维护各家 AI API 的完整 SDK。

## 当前项目能真正解决什么

- 明确减少 ArkTS/ArkUI 低级编译错误和状态刷新错误。
- 提高 AI 修改后的即时反馈质量，尤其是 Claude Code PostToolUse 场景。
- 降低 OHPM 假包、资源硬编码、权限/上架拒因等高频坑。
- 帮用户把构建错误用稳定 ID 和最小 diff 方式反馈给 AI。
- 让团队有一套跨工具共享的鸿蒙开发规则源。

## 做了也无法真正解决什么

- 无法保证 AI 生成代码一次通过 `hvigorw assembleHap`。scanner 是启发式，不能替代编译器和 DevEco SDK。
- 无法保证 AGC 一定通过审核。审核规则、人工判断、业务资质、隐私合规材料仍需人确认。
- 无法替代缺失的第三方 SDK。微信/地图/支付/推送等鸿蒙 SDK 是否可用，取决于供应商。
- 无法消除 API 版本变化。只能通过版本契约、官方文档索引、last_verified 日期降低漂移。
- 无法让 Cursor/Copilot 像 Claude Code 一样强制自修。没有等价 hook 的工具只能靠 pre-commit/CI 补强。
- 无法一键把 Android/iOS app 迁成原生鸿蒙 app。可做规划、映射和局部模板，但不能替代架构重构和真机验证。

## 过度设计风险

- 把 scanner 升级成大型 AST 编译器前端：维护成本高，短期不如接入 `hvigorw codeLinter` 和只读报告。
- 做完整 Android 到 HarmonyOS 自动迁移器：研究价值有，但超出本仓库“AI 开发护栏”定位。
- 把所有规则塞进 always-on 上下文：会让模型忽略重点，也会撞 Copilot/Cursor 的上下文限制。
- 自动执行 hdc 安装、AGC 提交、证书修改：风险高，应该让用户显式触发。
- 维护第三方 SDK 全量 cookbook：半衰期短，适合做贡献模板，不适合作为核心承诺。

## 参考来源

- ArkEval: <https://arxiv.org/abs/2602.08866>
- ArkTS-CodeSearch: <https://arxiv.org/abs/2602.05550>
- UITrans: <https://arxiv.org/abs/2412.13693>
- HarmonyOS 知识地图: <https://developer.huawei.com/consumer/cn/app/knowledge-map/>
- HarmonyOS 6 API 23 Developer Beta: <https://developer.huawei.com/consumer/cn/activity/developerbeta/harmonyos-developer-beta-6-5/>
- Claude Code hooks: <https://docs.claude.com/en/docs/claude-code/hooks>
- OpenAI Codex AGENTS.md: <https://developers.openai.com/codex/guides/agents-md>
- GitHub Copilot custom instructions: <https://docs.github.com/en/copilot/concepts/prompting/response-customization>
- Cursor rules: <https://docs.cursor.com/en/context>
- yibaiba/harmonyos-skills-pack: <https://github.com/yibaiba/harmonyos-skills-pack>
- FadingLight9291117/arkts_skills: <https://github.com/FadingLight9291117/arkts_skills>
- FadingLight9291117/mcp-harmonyos: <https://github.com/FadingLight9291117/mcp-harmonyos>
- ohosvscode/arkTS: <https://github.com/ohosvscode/arkTS>
