# 用 AI 助手开发鸿蒙应用（Claude Code / Codex / DevEco CodeGenie）

> **核心结论**：现阶段（2026 年）的通用 LLM（包括 Claude、Codex、ChatGPT、DeepSeek 等）对 ArkTS / ArkUI 的训练数据严重不足，**直接生成的代码往往违反 ArkTS 严格类型规则、混用 V1/V2 状态装饰器、错误使用 `@ohos.*` 旧命名空间**。把 AI 当成「会偶尔说错话的中级前端」，而不是权威。

## 1. 为什么 AI 在鸿蒙开发上特别容易出错

| 问题 | 原因 | 影响 |
| --- | --- | --- |
| ArkTS 是「low-resource language」 | GitHub 上 .ets 仓库少，公开训练数据稀缺 | 模型倾向回退到 TypeScript / React 写法 |
| ArkTS 有 70+ 项严格规则禁用 TS 特性 | `arkts-no-any`、`arkts-no-var`、`arkts-no-untyped-obj-literals` 等 | 看似合法的 TS 代码会被编译器拒绝 |
| 状态管理 V1 vs V2 同时存在 | API 12+ 引入 V2，V1 仍兼容 | 模型常混用 `@State` + `@ComponentV2` 等不兼容组合 |
| Kit 化 API（`@kit.*`）vs `@ohos.*` | API 12 起推荐 `@kit.*`，旧文档仍用 `@ohos.*` | 模型经常给出错误的 import 路径 |
| 装饰器、链式属性是 ArkUI 独有 | 与 React/SwiftUI 看似类似但不同 | 经典错误：在 `build()` 内创建对象、逻辑跑错语法位置 |

## 2. 总体策略

**「让 AI 写、人类校对、文档兜底」**：

1. AI 生成 → 立刻在 DevEco 内 **Run Code Linter** 与 **Build** 校验
2. 错误信息回灌 AI → 让它修
3. 仍不行 → 直接搜 `upstream-docs/openharmony-docs/zh-cn/` 中的权威 md
4. 把发现的修正规则**沉淀回 CLAUDE.md** 或 SKILL.md

**Claude Code 的本地资料优先级**（已写在 [`../CLAUDE.md`](../CLAUDE.md) 中）：

```
upstream-docs/openharmony-docs/zh-cn/application-dev/  ← 最权威
00–09 主题指南                                          ← 自创速查
互联网                                                  ← 兜底（容易陈旧）
```

## 3. 推荐工作流（DevEco Studio + Claude Code 协同）

DevEco Studio 是必须开的（它有官方 LSP、Inspector、Profiler、Linter、签名工具），Claude Code 跑在终端里读写代码。两者并行：

```
┌─────────────────────────┐         ┌─────────────────────────┐
│ DevEco Studio (IDE)     │         │ Terminal + Claude Code  │
│  · 真实编译 / Lint       │ ←文件→  │  · 读 upstream-docs     │
│  · Preview / Simulator  │         │  · 写代码 / 编辑文件    │
│  · 调试器               │         │  · 跑 hvigorw / hdc     │
└─────────────────────────┘         └─────────────────────────┘
```

**实操**：

1. 用 DevEco 创建好工程（在 `samples/` 下）
2. 终端进到工程目录，启动 Claude Code（`claude` 命令）
3. Claude 读 `oh-package.json5` / `module.json5` / 现有 `.ets`，理解上下文
4. 对话「在 pages/Detail.ets 里加一个详情页，从路由 param 读 id 后调 API…」
5. 改完后切回 DevEco 看 Linter / Editor 标红
6. 红色标记 / 编译错误 → 复制错误信息粘给 Claude 让它修
7. 通过后 Run 到模拟器验证

> 不要直接在 DevEco 里改代码后又让 Claude 改另一份，会冲突。**单一事实源是磁盘文件**。

## 4. 给 AI 的提示词模板（Claude / Codex 通用）

### 4.1 写新组件

```
我要在 entry/src/main/ets/pages/X.ets 加一个组件。

约束（请严格遵守）：
- HarmonyOS 6（targetSDK API 21 或 22，minSDK API 12），使用 ArkTS + ArkUI 声明式语法
- 装饰器只用 V1 系列（@Entry @Component @State @Prop @Link @Provide @Consume）
  ※ 不要用 V2（@ComponentV2 @Local @Param @Event）除非我明确要求
- import 全部走 @kit.*（例如 @kit.ArkUI / @kit.NetworkKit），禁止 @ohos.*
- 不要用 any / unknown / var；不要 obj[key] 索引；不要解构赋值
- 资源用 $r('app.media.x') $r('app.string.x')
- 给我一份完整可粘贴的 .ets 文件，先列要新增/修改的文件路径

参考本地资料：
- upstream-docs/openharmony-docs/zh-cn/application-dev/quick-start/arkts-get-started.md
- upstream-docs/openharmony-docs/zh-cn/application-dev/ui/state-management/
- 09-quick-reference/README.md（cheat sheet）
```

### 4.2 调系统 API

```
我需要从相册选一张图片然后上传到 https://example.com/upload。

约束：
- 用 @kit.CoreFileKit 的 picker（PhotoViewPicker）
- 用 @kit.NetworkKit 的 http
- 申请权限走 abilityAccessCtrl.requestPermissionsFromUser
- module.json5 中需要哪些 requestPermissions 一并列出
- 错误用 BusinessError 处理

请先在 upstream-docs/openharmony-docs/zh-cn/application-dev/reference/apis-core-file-kit/ 与
upstream-docs/.../reference/apis-network-kit/ 中验证 API 签名再写代码。
```

### 4.3 修编译错误

```
hvigorw assembleHap 报这些错（粘贴日志），所有报错文件已上传。

请：
1) 一一对应到具体的代码行
2) 区分「ArkTS 严格规则违反」与「业务逻辑错误」
3) 给最小修改方案，不要重写整个文件
4) 引用对应的 ArkTS rule（如 arkts-no-any / arkts-no-untyped-obj-literals）
```

## 5. 必须当面盯着 AI 检查的事项（Checklist）

### 装饰器

- [ ] 一个组件里只用 V1 或只用 V2，**不混用**
- [ ] `@Link` 调用方传参用 `$$xxx`（而不是直接 `xxx`）
- [ ] `@Watch` 字符串是已存在的方法名
- [ ] `@Prop` 传基础类型；引用类型要 `@ObjectLink` + `@Observed`
- [ ] V2 的 `@Param` 默认不可变；要可变用 `@Local`

### 类型

- [ ] 没有 `any` `unknown`
- [ ] 没有 `var`
- [ ] 没有 `obj['key']` 形式的动态索引
- [ ] 没有解构赋值（`const { a, b } = obj`）
- [ ] 对象字面量都有显式类型注解或对应类
- [ ] 类字段都已初始化（声明时或 constructor 里）

### Import

- [ ] 优先 `@kit.AbilityKit` `@kit.ArkUI` `@kit.NetworkKit`...
- [ ] 没有混用 `@ohos.app.ability.UIAbility` 与 `@kit.AbilityKit` 的同名 import
- [ ] 第三方 OHPM 包：先确认在 `oh-package.json5` `dependencies` 中

### ArkUI

- [ ] `build()` 里没有 `console.log` 之外的副作用（不能在 build 里 await / setState）
- [ ] `@Entry` 组件每个页面只有一个
- [ ] 状态变更用 `this.x = newVal`，不要 mutate 数组/对象（用展开或新对象替换）
- [ ] 资源引用用 `$r()`，路径正确

### 权限与配置

- [ ] 用了某 API，`module.json5` 里 `requestPermissions` 同步声明
- [ ] 路由新页面在 `main_pages.json` 里加上
- [ ] 新加 module，在工程级 `build-profile.json5` `modules` 里注册

## 6. AI 工具与生态（按推荐顺序）

### 6.1 MCP-HarmonyOS（最值得装）

把 AI 助手桥接到鸿蒙开发环境，用自然语言查询设备 / 项目 / 构建产物。

```bash
npm install -g mcp-harmonyos
```

Claude Desktop 配置（`~/Library/Application Support/Claude/claude_desktop_config.json`）：

```json
{
  "mcpServers": {
    "harmonyos": {
      "command": "mcp-harmonyos"
    }
  }
}
```

Claude Code 配置（在项目根 `.claude.json` 或全局）：

```json
{
  "mcpServers": {
    "harmonyos": { "command": "mcp-harmonyos" }
  }
}
```

GitHub：<https://github.com/fadinglight9291117/mcp-harmonyos>

提供的能力：
- 列出 hdc 连接的设备（型号、厂商、OS 版本）
- 解析 `app.json5` / `module.json5`
- 列出设备已安装应用
- 验证 HAP / HSP 构建产物

### 6.2 ArkTS 编程规范 Skill（Claude Code）

让 Claude 默认遵循 ArkTS 严格规则的内置 Skill：

- 来源 1：<https://mcpmarket.com/tools/skills/arkts-coding-standards-for-harmonyos>
- 来源 2：<https://github.com/aresbit/arkts-dev-skill>

把 SKILL.md 放进 `~/.claude/skills/` 或工程的 `.claude/skills/` 目录，Claude Code 会自动加载。

### 6.3 DevEco Studio 自带 CodeGenie / DeepSeek-R1

- DevEco Studio 6.x 内置 AI 代码助手（CodeGenie），免费接 DeepSeek-R1
- **侧边栏 AI 图标** → 输入提示词
- 优势：Huawei 训练，对 ArkTS / ArkUI 更准；可直接读项目上下文
- 劣势：交互不如 Claude Code 灵活，agent 能力弱

### 6.4 VS Code 的 ArkTS 插件（轻量补充）

如果某些场景想用 VS Code（启动比 DevEco 快得多）：

- **ArkTS Language Support** by `cheliangzhao`：<https://marketplace.visualstudio.com/items?itemName=cheliangzhao.arkts-language-support>（带 MCP）
- **ohosvscode/arkTS**（基于 Volar）：<https://github.com/ohosvscode/arkTS>，支持 codeLinter

> 注意：VS Code 不能签名、不能跑模拟器、不能调试。最终编译/调试还是回到 DevEco Studio。

### 6.5 DevEco 的 Code Linter（每次构建前必跑）

DevEco Studio 内置七套规则：

- `@typescript-eslint` 通用 TS
- `@security` 安全
- `@performance` 性能
- `@hw-stylistic` 鸿蒙代码风格
- `@correctness` 正确性
- `@cross-device-app-dev` 多端适配
- `@previewer` 预览器兼容

启用：**Code → Inspect Code** 或命令行 `hvigorw codeLinter`，14 条 ArkTS 规则支持一键自动修复。

## 7. 开发阶段（develop）注意事项

### 7.1 文件后缀语义

| 后缀 | 用途 |
| --- | --- |
| `.ets` | ArkTS UI 文件，含 `@Component` / `build()` |
| `.ts` | 普通 ArkTS 逻辑（无 UI） |
| `.d.ts` | 类型声明 |
| `.json5` | 配置文件（app/module/build-profile） |

> AI 经常把纯逻辑代码写到 `.ets` 里，或反过来在 `.ts` 里写 `@Component`。两者都会编译错。

### 7.2 项目目录硬性约束

- `entry/src/main/ets/pages/*.ets` 必须在 `resources/base/profile/main_pages.json` 注册
- `entry/src/main/ets/entryability/EntryAbility.ets` 与 `module.json5` 中 `abilities` 数组的 `srcEntry` 必须一致
- `AppScope/app.json5` 的 `bundleName` 必须与签名 profile 的 bundleName 完全一致

### 7.3 AI 写代码后必跑

```bash
# 编辑后立刻同步 + 编译
ohpm install                      # 如果改了依赖
hvigorw clean                     # 状态混乱时
hvigorw assembleHap -p buildMode=debug
hvigorw codeLinter                # 强烈建议
```

任何 ArkTS 错误用 `arkts-no-*` 编号 google + 查 `upstream-docs/`。

## 8. 调试阶段（debug）注意事项

### 8.1 Log 优先于断点

- 用 `hilog.info(0xDOMAIN, 'TAG', 'fmt %{public}s', value)`
- `%{public}s` 而非 `%s`：默认日志中 `s` 会被脱敏；放 public 模式才能看到内容
- DOMAIN 用 `0x0000`–`0xFFFF` 中你自己分配的，便于过滤

```bash
hdc hilog | grep MyTag
hdc hilog -L D|I|W|E|F          # 级别过滤
hdc hilog -c                    # 清空缓冲
```

### 8.2 ArkUI Inspector

- DevEco：**View → Tool Windows → ArkUI Inspector**
- 看组件树、属性、布局边界
- 选中节点反向定位 ets 源码
- AI 给的布局有问题时，肉眼比读代码快得多

### 8.3 Profiler

- **View → Tool Windows → Profiler**
- 录制 CPU / Memory / Frame
- 帧率掉到 60 以下时一帧的耗时点会被高亮

### 8.4 真机 vs 模拟器

| 能力 | 模拟器 | 真机 |
| --- | --- | --- |
| ArkUI / 路由 / 通用 API | ✅ | ✅ |
| HTTP / WebSocket | ✅ | ✅ |
| 文件读写 | ✅ | ✅ |
| 相机 | 部分 | ✅ |
| 蓝牙 / NFC | ❌ | ✅ |
| 定位 (真实 GPS) | ❌（mock） | ✅ |
| 推送（Push Kit） | ❌ | ✅ |
| 生物识别 | ❌ | ✅ |
| 多端协同 | 部分 | ✅ |

> AI 经常忘了某能力只能真机跑，结果模拟器永远调不出来。怀疑能力受限时先看本表。

### 8.5 常见错误码速查

| code | 含义 | 解 |
| --- | --- | --- |
| 201 | PERMISSION_DENIED | 在 `module.json5` 加权限 + 运行时申请 |
| 202 | 非系统应用 | 该 API 仅 system app；换 API |
| 401 | 参数错误 | 看官方签名 |
| 801 | 设备不支持 | `canIUse('SystemCapability.X')` 守护 |
| 16000050 | Ability 启动错误 | `module.json5` 中 ability 配置错误 |
| 9568305 | HAP 安装失败 | clean 重建；包过大；签名不一致 |
| 9568322 | 签名校验失败 | profile / cert 不匹配 |

## 9. 构建阶段（build）注意事项

### 9.1 构建模式

```bash
# Debug：体积大、有调试信息、可热更
hvigorw assembleHap -p buildMode=debug

# Release：开启混淆压缩、签名、可上架
hvigorw assembleApp -p buildMode=release
```

`build-profile.json5`：

```json5
{
  "buildOption": {
    "arkOptions": {
      "obfuscation": {
        "ruleOptions": {
          "enable": true,                                 // 开启混淆
          "files": ["./obfuscation-rules.txt"]
        }
      }
    }
  }
}
```

### 9.2 签名陷阱

- 调试 vs 发布证书 **必须分开**，profile 类型不一样
- `bundleName` 改了 → profile 失效，要重申请
- 上架包是 `.app`（含多个 hap），不是 `.hap`
- AI 经常给出 Android 风格的「keystore.jks」相关命令，鸿蒙是 `.p12` + `.cer` + `.p7b` 三件套

### 9.3 多模块构建顺序

工程级 `build-profile.json5` 的 `modules` 数组里**顺序无所谓**，Hvigor 自动按依赖图。但：

- HAR / HSP 模块必须在依赖它的 entry 之前**实际**编译（IDE 自动；CI 时要确认）
- 模块同名输出冲突会导致最终 .app 缺包

### 9.4 OHPM 依赖陷阱

- AI 经常推荐**不存在**的包名（特别是「@ohos/xxx」类前缀）
- 始终在 <https://ohpm.openharmony.cn/> 搜证
- `oh-package.json5` 改完后必须 `ohpm install`，否则 IDE 不会自动拉
- 大版本升级会破坏 V1 状态管理：例如 hypium 1→2

### 9.5 CI 脚本要点

```bash
export DEVECO_HOME=/Applications/DevEco-Studio.app/Contents
export PATH=$DEVECO_HOME/tools/ohpm/bin:$DEVECO_HOME/tools/hvigor/bin:$DEVECO_HOME/sdk/default/openharmony/toolchains:$PATH

ohpm install
hvigorw clean
hvigorw assembleApp -p buildMode=release \
  -p storeFile=$KEYSTORE_FILE \
  -p storePassword=$KEYSTORE_PWD \
  -p keyAlias=$KEY_ALIAS \
  -p keyPassword=$KEY_PWD \
  -p signAlg=SHA256withECDSA \
  -p profile=$PROFILE_FILE \
  -p certpath=$CERT_FILE
```

GitHub Actions 用 `macos-14`（arm64）+ 自托管 runner 装好 DevEco（License 限制无法在 hosted runner 装）。

## 10. 把约束写进 CLAUDE.md / SKILL.md

每次发现 AI 又踩同一个坑，把规则记到：

- `CLAUDE.md` 顶部的 "AI 助手必读" 段（Claude Code 自动加载）
- 工程根 `.claude/skills/<name>/SKILL.md`（按主题分散）
- 工程根 `AGENTS.md`（Codex / 其他 agent 默认读）

最小化结构：

```markdown
# Project AI Guidelines

## ArkTS 强制约束（违反则 PR 直接打回）
- import 走 @kit.* 不用 @ohos.*
- 装饰器：本项目用 V1
- 不写 any / var / 解构 / 索引访问
...

## 本项目特定约定
- 所有 API 调用走 src/main/ets/services/api/
- 错误统一抛 AppError（src/main/ets/types/error.ts）
...
```

## 11. 故障排查脚本（团队复用）

把验证流程封装：

```bash
# tools/precheck.sh
#!/usr/bin/env bash
set -e
ohpm install
hvigorw codeLinter
hvigorw assembleHap -p buildMode=debug
echo "✅ AI 生成的改动已通过基础校验"
```

每次 AI 改完跑一遍。

## 12. 参考链接

- TypeScript 到 ArkTS Cookbook（官方）：<https://developer.huawei.com/consumer/en/doc/harmonyos-guides/typescript-to-arkts-migration-guide>
- awesome-harmonyos（社区）：<https://github.com/HarmonyOS-Next/awesome-harmonyos>
- ArkTS 编程规范 Claude Skill：<https://github.com/aresbit/arkts-dev-skill>
- MCP-HarmonyOS：<https://github.com/fadinglight9291117/mcp-harmonyos>
- VS Code ArkTS Plugin：<https://github.com/ohosvscode/arkTS>
- ArkEval（学术评测，量化 AI 在 ArkTS 上的局限）：<https://arxiv.org/html/2602.08866>
