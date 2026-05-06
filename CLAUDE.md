# HarmonyOS DevSpace · Claude 使用指南

本目录是为「鸿蒙系统移动设备应用开发」准备的资料库与开发工作区。本文件供 Claude（或其他 AI 助手）在协助你开发鸿蒙应用时使用，告诉它在哪里查阅信息、按什么顺序回答问题、写代码时遵循什么规范。

> **跨工具通用硬约束** 在 [`AGENTS.md`](AGENTS.md)（[agents.md 标准](https://agents.md/)，24+ 工具兼容）。本文件 = AGENTS.md + Claude Code 特有扩展（Skills 触发索引、钩子说明、项目导航）。如果 AGENTS.md 与本文件冲突，**以 AGENTS.md 为准**。
>
> **当 Claude / Codex / 其他 AI 助手阅读本文件时**：第 0 节是硬约束，必须先看；再读第 2 节快速判断；遇到构建 / 调试 / 签名问题 → `harmonyos-build-debug` skill 自动触发，详细 references 见 [`.claude/skills/build-debug/references/develop-debug-build.md`](.claude/skills/build-debug/references/develop-debug-build.md)。
>
> **维护者文档清单（AI 写代码时不需要读）**：
> `docs/PLAN.md` / `docs/RESEARCH-NOTES.md` / `docs/REVIEW-*.md` / `docs/OPEN-SOURCE-STRATEGY.md` / `docs/USAGE-GUIDE.md` / `docs/MCP-INTEGRATION.md` / `docs/SETUP-FROM-SCRATCH.md` / `CHANGELOG.md` / `CONTRIBUTING.md` 是给项目维护者 / 新手装环境看的。除非用户明确问"项目怎么演进 / 怎么贡献 / 怎么装 DevEco / 怎么接 MCP"，**否则不要读它们**——读了浪费 context 也不影响你写鸿蒙代码。

---

## 0. AI 助手必读（最高优先级）

> ⚠️ **关键事实**：截至 2026 年，主流 LLM（含 Claude / Codex / GPT / DeepSeek）对 ArkTS / ArkUI 训练数据稀缺，会**习惯性写出 TypeScript 风格但 ArkTS 编译器拒绝的代码**。详细分析见 [`00-getting-started/05-ai-assisted-development.md`](00-getting-started/05-ai-assisted-development.md)。

### 0.1 写 ArkTS / .ets 之前必须遵守

**禁止的 TypeScript 特性**（详见 [`01-language-arkts/02-typescript-to-arkts-migration.md`](01-language-arkts/02-typescript-to-arkts-migration.md)）：

```
❌ any / unknown / var
❌ 对象字面量没有显式 class/interface 类型注解
❌ obj['key'] 形式的动态索引（用 Map<K,V>）
❌ 解构赋值 const { a, b } = obj
❌ function 表达式（用箭头函数）
❌ 私有字段 # 前缀（用 private 关键字）
❌ /regex/ 字面量（用 new RegExp）
❌ 索引签名 [k:string]:T（用 Map 或具体字段）
❌ Symbol / 类表达式 / 条件类型 / 交叉类型
❌ delete 操作符（设为 null）
❌ 一元 + 转换（用 parseInt / Number()）
❌ for...in（用普通 for）
❌ 类字段未初始化（声明时或 constructor 必须赋值）
❌ 结构性类型（class A 与 class B 不能因字段相同而互换）
```

**Import 必须用 Kit 化路径**（HarmonyOS 5 起的官方推荐）：

```typescript
// ✅ 推荐
import { http } from '@kit.NetworkKit';
import { window } from '@kit.ArkUI';
import { UIAbility, AbilityConstant, Want, common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';

// ⚠️ 仍可编译但属旧式
import http from '@ohos.net.http';
```

### 0.2 ArkUI 状态管理硬约束

**绝不混用 V1 与 V2**：一个 `.ets` 文件里要么全 V1 要么全 V2。

| 场景 | V1 | V2（API 12+，类型更严） |
| --- | --- | --- |
| 组件 | `@Component` | `@ComponentV2` |
| 私有状态 | `@State` | `@Local` |
| 父→子单向 | `@Prop` | `@Param`（不可变；要可变用 `@Local`） |
| 父↔子双向 | `@Link`（传参 `$$xxx`） | 不直接对应；用 `@Param` + `@Event` 回调 |
| 仅初始化一次 | — | `@Once @Param` |
| 跨层级 | `@Provide` / `@Consume` | `@Provider()` / `@Consumer()` |
| 引用对象 | `@Observed` 类 + `@ObjectLink` | `@ObservedV2` 类 + `@Trace` 字段 |
| 监听 | `@Watch('cb')` | `@Monitor('path')` |
| 派生计算 | 手写 | `@Computed get x() { ... }` |
| 全局存储 | `@StorageProp` / `@StorageLink` | 同 V1，未弃用 |

**新项目用 V2 更安全**（编译期类型更严格）；**改老项目按现有装饰器风格延续**，不要混用。

### 0.3 生成代码后必跑的验证

```bash
ohpm install                            # 改了依赖才需要
hvigorw codeLinter                      # ArkTS 规则强校验
hvigorw assembleHap -p buildMode=debug  # 真编译
```

任何 `arkts-no-*` 错误：在 [`01-language-arkts/02-typescript-to-arkts-migration.md`](01-language-arkts/02-typescript-to-arkts-migration.md) 搜该编号；不会修就在 `upstream-docs/openharmony-docs/zh-cn/application-dev/quick-start/arkts-migration-background.md` 找答案。

> 💡 **本仓库已配 PostToolUse 钩子**：你（Claude Code）每次 Edit / Write / MultiEdit 修改 `.ets` / `.ts` / `oh-package.json5` 后，钩子会自动触发：
>
> - `tools/hooks/lib/scan-arkts.sh` 扫描 ArkTS 反模式（含 STATE-002 / STATE-008 / ARKTS-001/003/004/005/008/009/012/014 等）
> - `tools/check-ohpm-deps.sh` 校验 OHPM 包名是否真实存在
> - 结果会回喂到你的下一轮上下文（stderr）+ 写入 `.claude/.harmonyos-last-scan.txt`
>
> **如果你看到这个文件，请先读它**——它含有上一次扫描的违规列表，应当先修这些再继续。

### 0.4 不要凭记忆 / 训练数据写 API 签名

ArkTS / ArkUI / Kit API 在 API 12 → 14 → 18 → 20 → 21 → 22 期间多次变化。AI 训练数据通常停留在 API 9-11 的旧版。**必须查证后再写**：

1. 先在 `upstream-docs/openharmony-docs/zh-cn/application-dev/reference/` 搜对应 Kit
2. 找不到再上 [developer.huawei.com](https://developer.huawei.com/consumer/cn/) 查官网
3. 仍不确定就告诉用户「我无法验证此 API 当前形态，建议你在 IDE 里 Ctrl+点进类型定义确认」

不要编 API。

### 0.5 状态更新必须替换引用，禁止就地 mutation（统计学第一大坑）

> **数据**：ArkEval 基准（arxiv 2602.08866）显示 LLM 在 ArkTS 上的错误分布：**42% UI 状态失同步**、35% 严格类型违规、23% 生命周期误用。"`@State` 数组就地 push" 是单一最常见的 bug。

ArkUI 状态系统**只追踪引用替换**，不监听对象内部修改。下面四类操作不会触发重渲染：

```typescript
// ❌ 数组：就地 push / pop / splice / sort / reverse
this.list.push(x);
this.list.splice(0, 1);
this.list.sort();

// ❌ 对象：就地修改字段（除非该类被 @Observed / @ObservedV2 修饰）
this.user.name = 'Alice';

// ❌ Map / Set：调用 set / delete / clear（外层若是 @State，仍需替换）
this.cache.set('k', 'v');

// ❌ 嵌套对象的深层字段（即使外层加了 @Observed，深层未追踪也不更新）
this.profile.address.city = 'Beijing';
```

**正确写法**：

```typescript
// ✅ 数组：替换整个引用
this.list = [...this.list, x];
this.list = this.list.filter(i => i.id !== id);
this.list = this.list.map(i => i.id === id ? { ...i, done: true } : i);

// ✅ 对象：用展开运算符创建新对象
this.user = { ...this.user, name: 'Alice' };

// ✅ V1：对象字段需要响应式 → 类加 @Observed，引用变量加 @ObjectLink
@Observed class User { name: string = ''; }

// ✅ V2：类用 @ObservedV2，要响应的字段加 @Trace
@ObservedV2 class User { @Trace name: string = ''; }

// ✅ Map / Set：替换为新实例
const next = new Map(this.cache);
next.set('k', 'v');
this.cache = next;
```

**辅助验证**：写完任何状态变更后，自问"我刚才有没有重新赋值这个 `@State` / `@Local` 字段的引用？"。没有的话 UI 一定不会刷新。

---

## 1. 项目背景

- **目标平台**：HarmonyOS 6 系列
  - **API 22（HarmonyOS 6.0.2）**：当前消费版稳定线，2026-01-23 起向 Mate 80 / Mate 70 / Pura 80 等推送
  - **API 21（HarmonyOS 6.0.1）**：2025-11-25 随 Mate 80 首发的稳定版
  - **API 20（HarmonyOS 6.0.0）**：2025-09-25 仅开发者版（developer release），非消费稳定版，不要在生产 app targetSDK 选它
  - **HarmonyOS 6.1 开发者 Beta**：2026-02-07 对约 5 万名中国开发者开放，关注新特性可选用
  - **向下兼容 HarmonyOS 5（API 12+）**：仍是大部分应用的最低 minSDK
- **开发设备**：Mac（Apple Silicon，macOS 26.5）
- **主语言**：ArkTS（TypeScript 增强版）
- **UI 框架**：ArkUI（声明式）
- **IDE**：DevEco Studio 6.x（自带 SDK / Node / Hvigor / OHPM / 模拟器）
- **包管理**：OHPM（OpenHarmony Package Manager）
- **构建工具**：Hvigor
- **设备调试**：hdc（HarmonyOS Device Connector，类似 adb）

> **新项目 targetSDK 默认建议**：API 21，minSDK API 12。需要 6.0.2 新能力（如更新过的 Kit 接口）才上 API 22。
>
> 自 2025-06-20 起，"HarmonyOS NEXT" 后缀已被官方弃用，统一称作 HarmonyOS 6 / 5。文档中出现的 "NEXT" 与现行 HarmonyOS 是同一系统线（纯鸿蒙、不再兼容 Android）。

---

## 2. 快速判断（Claude 必读）

| 用户在问什么 | 优先去哪里 |
| --- | --- |
| "怎么装 DevEco / 配环境" | `00-getting-started/` |
| "ArkTS 怎么写 / 装饰器" | `01-language-arkts/` + `upstream-docs/.../quick-start/arkts-*.md` |
| "ArkUI 组件 / 状态管理 / 布局" | `02-framework-arkui/` + `upstream-docs/.../ui/` 与 `reference/apis-arkui/` |
| "调用某个 API / 系统能力" | `03-platform-apis/` + `upstream-docs/.../reference/` |
| "hdc / 签名 / 打包 / Hvigor / OHPM" | `04-build-debug-tools/` |
| "性能 / 多设备适配 / 安全 / 包大小" | `05-best-practices/` + `upstream-docs/.../performance/` |
| "UI/UX 规范 / 设计语言" | `06-design-guidelines/` + `upstream-docs/zh-cn/design/ux-design/` |
| "上架 AppGallery / 应用市场" | `07-publishing/` |
| "找官方权威链接" | `08-resources-links/` |
| "快速查 cheat sheet" | `09-quick-reference/` |

---

## 2.5 Skills 触发索引

`.claude/skills/` 下的 5 个 SKILL.md 由 Claude Code 按 frontmatter 自动激活。下表是手动判断时的索引：

| 用户场景 | 应激活的 skill | 核心内容 |
| --- | --- | --- |
| 写 / 改 `.ets` / `.ts` 鸿蒙文件 / 迁 TS 代码 / `arkts-no-*` 报错 | `arkts-rules` | ArkTS 严格规则、TS 反模式改写 |
| 用状态装饰器 / "UI 不刷新" / V1 vs V2 选型 | `state-management` | 替换引用铁律、V1/V2 对照、错误诊断 |
| 打包 / Hvigor / OHPM / hdc / 错误码诊断 | `harmonyos-build-debug` | 三种产物、命令速查、错误码 |
| 配签名 / 申请证书 / AGC 上架 / 审核被拒 | `harmonyos-signing-publish` | 三件套、AGC 流程、Top 20 拒因 |
| review 鸿蒙代码 / PR 审查 / 上架前自查 | `harmonyos-review` | 9 大类 60+ 编号规则扫描 + 报告模板 |

**Edit 后自动校验**：本仓库已配 PostToolUse 钩子（`.claude/settings.json`）。每次 `Edit` / `Write` / `MultiEdit` 完 `.ets` / `.ts` / `oh-package.json5` 后会自动跑 `tools/hooks/post-edit.sh`：

- `tools/hooks/lib/scan-arkts.sh` ArkTS 反模式 grep 扫描
- `tools/check-ohpm-deps.sh` OHPM 包名校验
- 违规写入 stderr + `.claude/.harmonyos-last-scan.txt`

如果你在 Edit 前看到 `.claude/.harmonyos-last-scan.txt` 存在且非空，**先读它**——含有上一次扫描的违规列表，应当先修这些再继续。

---

## 3. 目录布局

```
HarmonyOS_DevSpace/
├── CLAUDE.md                   ← 本文件（AI 总入口）
├── AGENTS.md                   ← 给 Codex / Cursor / Aider 等的简版规则
├── README.md                   ← 给人类用户看的总览
├── LICENSE                     ← MIT；upstream-docs 单独 CC-BY-4.0
├── llms.txt                    ← LLM 爬虫友好的索引（人也能读）
├── .mcp.json                   ← MCP-HarmonyOS 服务配置
├── .gitignore                  ← 鸿蒙生态调过的 ignore 列表
├── .claude/
│   ├── settings.json           ← PostToolUse 钩子配置
│   └── skills/                 ← 5 个按需触发 SKILL.md（详见 § 2.5）
├── tools/                      ← 钩子 / 校验 / 安装 / fan-out 脚本
│   ├── hooks/                  ← post-edit.sh + lib/* + test-fixtures/
│   ├── install.sh              ← curl-pipeable 安装到 app
│   ├── check-ohpm-deps.sh      ← OHPM 包名校验
│   ├── run-linter.sh           ← 离线 codeLinter wrapper
│   ├── generate-ai-configs.sh  ← 真单源 fan-out 到 Cursor/Copilot
│   ├── bootstrap-upstream-docs.sh  ← 拉官方文档镜像
│   ├── verify-environment.sh
│   └── install-deveco-prereqs.sh
├── .cursor/rules/harmonyos.mdc ← fan-out 生成（不要手改）
├── .github/                    ← workflows / copilot-instructions.md（fan-out 生成）
─── 维护者文档（AI 写代码不需要读，全部在 docs/）─────────────
├── docs/
│   ├── PLAN.md                 ← 施工方案 / 调研 / 决策
│   ├── OPEN-SOURCE-STRATEGY.md ← 三层发布策略（指针到 PLAN）
│   ├── RESEARCH-NOTES.md       ← 同类项目调研档案（指针到 PLAN）
│   ├── USAGE-GUIDE.md          ← 进阶使用方式（多 app 共享 / 三层发布）
│   └── REVIEW-2026-05-06.md    ← 第三方评审存档
├── CHANGELOG.md                ← 版本变更
├── CONTRIBUTING.md             ← 贡献指南
─── 主题目录（按 § 2 路由表查询）─────────────────────────────
├── 00-getting-started/         ← 环境搭建、首个项目、签名、AI 协作
├── 01-language-arkts/          ← ArkTS 语言：装饰器、TS 差异、状态速查
├── 02-framework-arkui/         ← ArkUI 声明式 UI、状态管理、动画
├── 03-platform-apis/           ← 系统能力分类索引（媒体/网络/...）
├── 04-build-debug-tools/       ← Hvigor / OHPM / hdc / DevEco 调试器
├── 05-best-practices/          ← 性能、多端适配、安全、包大小
├── 06-design-guidelines/       ← 鸿蒙设计语言、控件规范
├── 07-publishing/              ← AppGallery Connect、签名证书、分发
├── 08-resources-links/         ← 精选官方/社区链接清单
├── 09-quick-reference/         ← 备忘录式 cheat sheet
├── samples/                    ← 示例代码（路线图见目录 README）
├── tools/                      ← 安装脚本、辅助工具
└── upstream-docs/
    └── openharmony-docs/       ← OpenHarmony 官方完整文档（中英双语，CC-BY-4.0）
        ├── zh-cn/
        │   ├── application-dev/   ← 应用开发（最常用）
        │   ├── design/            ← 设计规范
        │   ├── release-notes/
        │   └── third-party-cases/
        └── en/...
```

`upstream-docs/openharmony-docs/` 是从官方 GitHub 镜像 (`openharmony-rs/openharmony-docs`，对应 Gitee 上 `openharmony/docs`) 全量克隆的中英文文档，约 5300+ 篇 zh-cn markdown 与 5100+ 篇 en markdown，是最权威的本地参考。

---

## 4. 检索约定（Claude 必读）

回答用户问题时遵循以下顺序：

1. **优先读 `upstream-docs/openharmony-docs/zh-cn/application-dev/`** —— 这是 OpenHarmony 官方最权威的中文文档源，覆盖应用开发全部主题
2. 用 `Grep` / `Glob` 在 `upstream-docs/openharmony-docs/zh-cn/application-dev/` 下按关键词搜索，例如：
   - 学 ArkTS 装饰器：`@State` `@Prop` `@Link` `@Provide` `@Consume` `@Watch` 在 `ui/state-management/` 目录
   - 找 UI 组件：搜 `arkts-common-components-*.md` 或 `reference/apis-arkui/arkui-ts/ts-basic-components-*.md`
   - 找 API：搜 `reference/apis-*` 子目录
3. **本地同主题文件优先于网络搜索**，仅当本地资料缺失或版本陈旧时才上网
4. 若需要权威外部资料，参见 [`08-resources-links/README.md`](08-resources-links/README.md)
5. 找不到对应内容时直接告诉用户「本地资料没有，建议查看 XYZ 链接」，不要编造 API

---

## 5. 编码与回答规范

### ArkTS / ArkUI 代码

- 文件后缀使用 `.ets`（ArkTS UI 文件），普通逻辑用 `.ts`
- 入口组件用 `@Entry @Component struct Index { ... }` 声明，UI 写在 `build()` 内
- 状态管理装饰器顺序约定：`@State` 私有，`@Prop` 父→子单向，`@Link` 父↔子双向，`@Provide / @Consume` 跨层级
- 资源引用：图片放 `resources/base/media/`，字符串放 `resources/base/element/string.json`，通过 `$r('app.media.xxx')` `$r('app.string.xxx')` 引用
- 入口 `module.json5` 与 `app.json5` 中的 `bundleName` `vendor` `versionCode` 必须与签名证书匹配
- `import` 模块来自 `@kit.*`（Kit 模块化 API，HarmonyOS 5 起的推荐写法）或 `@ohos.*`（旧版命名空间）

### 项目结构（Stage 模型）

```
MyApp/
├── AppScope/             ← 应用级公共资源
├── entry/                ← 默认 entry HAP
│   ├── src/main/ets/     ← ArkTS 源码
│   │   ├── pages/
│   │   ├── entryability/
│   │   └── entrybackupability/
│   ├── src/main/resources/
│   ├── src/main/module.json5
│   └── build-profile.json5
├── build-profile.json5
├── hvigorfile.ts
├── oh-package.json5      ← 依赖（类似 package.json）
└── oh_modules/           ← 安装后的依赖（类似 node_modules）
```

- HarmonyOS 应用强制使用 **Stage 模型**（FA 模型已废弃，仅历史项目仍在维护）
- 主入口为 `EntryAbility`，UIAbility 绑定 `WindowStage` 显示页面

### 回答风格

- 中文回答，专业术语保留英文（ArkTS / Stage / Ability / Hvigor / OHPM 等）
- 给出可直接编译运行的最小代码片段，附上文件路径
- 当用户问「为什么」类问题，引用 `upstream-docs/...` 中具体 md 路径作为依据

---

## 6. 环境状态速查

| 项目 | 状态 / 推荐版本 |
| --- | --- |
| OS | macOS 26.5（Apple Silicon arm64） |
| Homebrew | 已就绪 (`/opt/homebrew`) |
| Node.js | 已有 v22；DevEco 6.x 内置 Node 18.20.x，建议 IDE 内使用其内置版本，CLI 用系统 Node 22 |
| JDK | DevEco 自带 JBR（JetBrains Runtime），不需要单独装 JDK |
| DevEco Studio | 安装步骤见 [`00-getting-started/02-deveco-studio-install.md`](00-getting-started/02-deveco-studio-install.md) |
| HarmonyOS SDK | DevEco 安装时随之配置 |
| hdc CLI | 装在 `<DevEco>/Contents/sdk/<api>/openharmony/toolchains/hdc`，需手动加 PATH |
| OHPM | 同上路径下的 `oh-package` |
| 签名证书 | 通过 AGC（AppGallery Connect）申请，详见 [`07-publishing/`](07-publishing/) |

---

## 7. 任务模板提示

当 Claude 接收到以下类型任务时，建议遵循下述模板：

### 「帮我写一个 X 页面 / 组件」
1. 在 `samples/` 下创建文件
2. 用 `@Entry @Component struct` 声明
3. 状态管理优先用 `@State`，跨组件用 `@Link`
4. 引用资源用 `$r('app.media.*')`
5. 给出对应的 `pages/Index.ets` 入口注册（如果是路由）
6. 列出需要在 `module.json5` 加的权限或 abilities

### 「调用某个系统 API」
1. 先在 `upstream-docs/.../reference/apis-*` 中找权威签名
2. 注意检查所需 SystemCapability 与权限（`ohos.permission.*`）
3. 写示例时连同 `requestPermissionsFromUser` 流程一并展示
4. 错误处理用 `BusinessError` 类型

### 「打包 / 调试 / 签名」
1. 调用 hvigor 命令：`hvigorw assembleHap` / `assembleApp`
2. 调试设备列表：`hdc list targets`
3. 安装：`hdc install xxx.hap` 或 `hdc app install xxx.app`
4. 详细签名流程见 [`07-publishing/README.md`](07-publishing/README.md)

---

## 8. 已知限制

- 真机调试需要在华为开发者联盟实名认证后申请调试证书；**模拟器**在 DevEco 内自带（API 12+），可用于 UI 与多数 API 调试，但部分硬件能力（NFC、GPS 等）需要真机
- 部分文档（如 ArkUI-X 跨平台、AGC SDK 详细参数）在 OpenHarmony 开源仓库中不完整，需要回到 [developer.huawei.com](https://developer.huawei.com/consumer/cn/) 查阅
- 上架 AppGallery 必须使用华为开发者账号（非个人开发者 99 ¥/年，企业 600 ¥/年）

---

## 9. 维护说明

更新文档：

```bash
cd upstream-docs/openharmony-docs
git pull --depth=1 origin master   # 若 .git 已被删除，重新 clone
```

或者完全重新克隆（含历史）：

```bash
cd upstream-docs && rm -rf openharmony-docs
git clone https://github.com/openharmony-rs/openharmony-docs.git
```

新增本地 markdown 时，命名规范：`NN-topic-subtopic.md`，前缀编号便于排序。

---

## 10. AI 协作工作流（推荐）

DevEco Studio 与 Claude Code / Codex 并行使用：

```
┌─────────────────────────┐         ┌─────────────────────────┐
│ DevEco Studio (IDE)     │         │ Terminal + Claude Code  │
│  · 编译 / Code Linter   │ ←文件→  │  · 读 upstream-docs     │
│  · Preview / Simulator  │         │  · 写代码 / 编辑文件    │
│  · 调试器 / Inspector   │         │  · 跑 hvigorw / hdc     │
└─────────────────────────┘         └─────────────────────────┘
```

详细规则：[`00-getting-started/05-ai-assisted-development.md`](00-getting-started/05-ai-assisted-development.md)

**强烈推荐安装的 AI 增强工具**：

- **MCP-HarmonyOS**（让 AI 直接查设备 / 项目 / 构建状态）：`npm install -g mcp-harmonyos`
- **DevEco 自带 CodeGenie / DeepSeek-R1**（针对鸿蒙训练，对 ArkTS 更准）
- **DevEco Code Linter**（每次构建前必跑：`hvigorw codeLinter`，或本仓库的 `tools/run-linter.sh`）

**本仓库自带的工具（一键到位）**：

| 工具 | 作用 |
| --- | --- |
| `.claude/settings.json` PostToolUse 钩子 | Claude Code 每次 Edit/Write 后自动跑 ArkTS + OHPM 校验 |
| `tools/hooks/lib/scan-arkts.sh` | grep-based 反模式扫描，毫秒级 |
| `tools/check-ohpm-deps.sh` | OHPM 包名黑/白名单 + ohpm CLI 校验 |
| `tools/run-linter.sh` | 包装 hvigorw codeLinter，不依赖 DevEco GUI |
| `tools/install.sh` | 把规则一行装到任意鸿蒙 app（curl pipe-able） |
| `tools/generate-ai-configs.sh` | 单源 fan-out 到 Cursor `.mdc` / Copilot instructions |
| `tools/bootstrap-upstream-docs.sh` | 拉取 OpenHarmony 官方文档镜像 |
| `tools/hooks/test-fixtures/` | 故意写错的 .ets 用于校验脚本回归 |

---

## 11–13. 开发 / 调试 / 构建注意事项（已拆出按需加载）

> **§ 11-13 的详细内容已挪到 [`.claude/skills/build-debug/references/develop-debug-build.md`](.claude/skills/build-debug/references/develop-debug-build.md)**——含文件后缀语义、Stage 模型约束、IDE 报红 vs 编译报错、hilog 格式、ArkUI Inspector / Profiler 流程、模拟器 vs 真机能力差、错误码表、签名三件套、release 构建命令、混淆配置、CI 注意事项等共 ~150 行。
>
> Claude Code 在 `harmonyos-build-debug` skill 触发时（用户提到 hvigorw / hdc / 错误码 / 模拟器 / 签名等）会读到。**这里只保留高频引用的精华**：

### 11.1 写完代码必跑

```bash
ohpm install                            # 改了 oh-package.json5
hvigorw codeLinter                      # ArkTS 规则
hvigorw assembleHap -p buildMode=debug  # 真编译
```

### 11.2 不允许的依赖

- 不能 `import` npm 包（除非也发到 OHPM）
- AI 常推荐 axios / lodash / moment → 在 ArkTS 里改用 `@kit.NetworkKit` http / 自写 / `@kit.LocalizationKit`
- 发现别人在依赖里加 `@ohos/lottie-player`（不存在）/ `@ohos/axios`（不存在）等：钩子 `tools/check-ohpm-deps.sh` 会拦截

### 11.3 文件类型分发

`.ets` 含 UI（`@Component` / `build()`）；`.ts` 纯逻辑；不要把 UI 写到 `.ts`。

### 11.4 错误码 Top 7（详见 references）

```
201 PERMISSION_DENIED · 401 参数错误 · 801 设备不支持
9568305 HAP 安装失败 · 9568322 签名校验失败
16000050 Ability 启动失败 · 202 非系统应用
```

---

## 14. 任务请求模板

任务请求模板（贴给用户参考）已挪到 [`docs/USAGE-GUIDE.md` § 任务模板](docs/USAGE-GUIDE.md)。这是低频内容（用户在跟 AI 提需求时偶尔参考），不需要每轮注入到 AI 上下文。
