---
name: runtime-pitfalls
verified_against: harmonyos-6.1.0-api23  # last sync 2026-05-22
description: |
  鸿蒙工程**运行时装配陷阱**——ArkTS 语法无错但项目跑不起来 / 行为不正确的工程层坑。
  来源：真实 LLM 对话客户端 app M3-M13 + paseo-harmony Phase A/B 实战反馈。
  **激活条件**（满足任一即激活）：
    - 修改 `build-profile.json5` / `module.json5` / `oh-package.json5` 任意一个
    - 改 `resources/*/element/string.json` 或其他资源文件
    - 实现主题切换 / 跟随系统外观（涉及 `@StorageLink('appearanceTheme')`）
    - 在 Web 组件上注册 `javaScriptProxy` / 实现 H5 ↔ ArkTS 桥
    - 写多模态 LLM 调用（OpenAI Vision / Whisper / DALL-E 等）
    - 多模块工程（feature 拆分）+ 模块改名
    - HUKS 加密集成（API key / 用户敏感数据落盘）
    - 替换品牌图标 / 修改 `AppScope/resources/base/media/{background,foreground}.png`（layered icon）
    - 改 `NavPathStack` 路由 / 在 `build()` 写多个根 container / 实现长列表 timeline
    - 多 host 共享存储（per-host store 按 serverId 分桶）/ daemon workspaceId 字段消费
  **不激活**：纯 UI 组件、纯算法逻辑、单 module hello world。
---

# 鸿蒙运行时装配陷阱

> 触发场景：**ArkTS 编译能过但 app 跑不起来 / 行为不对**。这一层 grep 扫不出来，靠 AI 主动避免。
>
> 来源：真实 LLM 对话 app M3-M13 工程踩坑总结 + paseo-harmony Phase A/B（Splash 白屏 / emoji / Button padding / build() root / timeline timestamp / per-host store / workspaceId）+ LCC 真机部署（layered icon foreground 透明）。共 17 章，编号一～十七。

## 一、主题切换 / 外观跟随

### 现象
代码改了 `appearanceTheme` 状态值，但页面 UI 不重渲染——颜色、字号没变。

### 原因
鸿蒙的"主题切换"必须满足**两个条件同时成立**：

1. **Tokens 必须是函数式 token**（不是常量），返回值依赖 `appearanceTheme`
2. **使用 token 的组件必须订阅** `@StorageLink('appearanceTheme')` 让该字段变化能触发 build()

只满足其一 → token 值变了但 UI 不刷新 / UI 想刷但拿不到新 token。

### 正确写法

```typescript
// tokens.ts —— 函数式 token，每次调用按当前主题读
export function colorTextPrimary(): ResourceColor {
  return AppStorage.get<string>('appearanceTheme') === 'dark'
    ? $r('app.color.text_primary_dark')
    : $r('app.color.text_primary_light');
}

// MyPage.ets —— 必须订阅 appearanceTheme 才会重渲染
@Entry @Component
struct MyPage {
  @StorageLink('appearanceTheme') theme: string = 'light';   // ⚠️ 必须有这行
  build() {
    Text('hi').fontColor(colorTextPrimary());   // theme 变 → 重 build → 拿到新 token
  }
}
```

### 反模式
```typescript
// ❌ 只在 settings 页改 AppStorage.set('appearanceTheme', 'dark')
// ❌ ChatPage 没 @StorageLink('appearanceTheme') → 主题切了 ChatPage 不刷
```

## 二、useNormalizedOHMUrl 强制 scope import

### 现象
`build-profile.json5` 里 `useNormalizedOHMUrl: true`（HarmonyOS 6 IDE 模板 / DevEco 5.0+ 默认开启；HarmonyOS 5 时代多数模板也是 true，但可手动设 false 关闭），跨模块 import 写 `import { Foo } from '../common/foo'` 报错 "path resolution failed"。

### 原因
启用规范化 OHM URL 后，模块间引用**必须走 `@ohos/<module-name>` scope**，不能用相对路径。

### 正确写法

```typescript
// feature 模块的 entry 引用 common 模块
// ❌ 不行
import { ChatStore } from '../../../common/src/main/ets/store';

// ✅ 正确（前提：oh-package.json5 里 dependencies 加 "@ohos/common")
import { ChatStore } from '@ohos/common';
```

### 集成步骤

```json5
// feature/oh-package.json5
{
  "dependencies": {
    "@ohos/common": "file:../common"
  }
}
```

## 三、模块重命名 · 三处必须同步

### 现象
重构期把 `feature_a` 改成 `chat`，编译报错 "module not found"。

### 原因
鸿蒙模块名在 **3 处**记录，必须同时改：

```
build-profile.json5         modules[].name          ← 工程级模块声明
<module>/module.json5       module.name             ← 运行时模块名
<module>/oh-package.json5   name                    ← OHPM 包名（@ohos/<这个> 或不带前缀）
```

漏改任意一处 → build 失败或运行时找不到模块。

### ⚠️ 关键：build-profile 与 module.json5 是**字面量等于**关系

`build-profile.json5` 中 `modules[].name` 是**模块标识**（不是 OHPM 包名），它必须 **逐字符等于** `<module>/src/main/module.json5` 中 `module.name`。

报错原文（重命名漏改时）：

```
The module name conversation in build-profile.json5 must be same as moduleName in module.json5.
```

OHPM 包名（`@ohos/<name>`）是**另一层**，在 `oh-package.json5`，可与之独立（带 `@ohos/` 前缀或不带都行）。

### 自动化校验
```bash
bash tools/check-rename-module.sh
```
会对照三处 name 是否一致。**v0.5 修复**：原版本对 DevEco 默认模板（含 JSON5 尾逗号 `{ "name": "debug", }`）会 jq 解析失败；现在已正确去尾逗号。

## 四、string.json "string" 数组不允许为空

### 现象
DevEco "Empty Ability" 模板自带 `EntryAbility_label` 等字符串。删干净后只剩 `"string": []`，编译报错 "Required attribute 'string' must be a non-empty array"。

### 正确写法

```json
{
  "string": [
    { "name": "_placeholder", "value": "" }
  ]
}
```

至少留一个 placeholder。本仓库的 scan-arkts.sh 加了 `STRING-JSON-EMPTY` 规则会自动检测。

## 五、Web 组件 javaScriptProxy 必须稳定实例

### 现象
H5 → ArkTS 桥（`javaScriptProxy`）注册后，每次组件 build() 都重建 proxy 对象 → 桥丢失，H5 调用 `window.reporter.report(...)` 失败。

### 原因
`Web().javaScriptProxy({...})` 的对象引用必须**整个组件生命周期内稳定**。在 build() 内 inline 写 `javaScriptProxy({ object: { fn: () => {...} } })` → 每次重渲染就重建。

### 正确写法

```typescript
@Component struct WebContainer {
  // ⚠️ proxy 实例在 aboutToAppear 建一次，整个组件生命周期复用
  private reporter: ReporterProxy | null = null;

  aboutToAppear(): void {
    this.reporter = new ReporterProxy();
  }

  build() {
    Web({ src: 'resource://rawfile/index.html', controller: ... })
      .javaScriptProxy({
        object: this.reporter,           // ✅ 引用稳定
        name: 'reporter',
        methodList: ['report'],
        controller: ...
      })
  }
}
```

### 反模式
```typescript
// ❌ 每次 build 都重建
.javaScriptProxy({
  object: { report: (data: string) => { /* ... */ } },   // ← 字面量每次新建
  name: 'reporter',
  methodList: ['report'],
})
```

## 六、HUKS 加密 API key（上架强制）

### 现象
`apiKey: string` 用 Preferences 明文存盘 → AGC 提审被拒（`SEC-001`）。

### 正确模式（最小骨架）

```typescript
import { huks } from '@kit.UniversalKeystoreKit';
import { preferences } from '@kit.ArkData';

const KEY_ALIAS = 'app_apikey_v1';

class SecretStore {
  private prefs: preferences.Preferences | null = null;

  async init(): Promise<void> {
    this.prefs = await preferences.getPreferences(getContext(), 'secrets');
    // 第一次启动时生成 HUKS key（已存在则 generateKey 抛异常，吞掉）
    try {
      const opts: huks.HuksOptions = { properties: [
        { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
        { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
        // ... 完整 properties 见官方文档
      ]};
      await huks.generateKeyItem(KEY_ALIAS, opts);
    } catch (e) { /* already exists */ }
  }

  async saveApiKey(plain: string): Promise<void> {
    const ciphertext = await this.encrypt(plain);
    await this.prefs!.put('apiKey', ciphertext);
    await this.prefs!.flush();
  }

  async loadApiKey(): Promise<string | null> {
    const v = await this.prefs!.get('apiKey', '') as string;
    if (!v) return null;
    // 兼容历史明文：v 不像密文格式则直接返回（一次迁移）
    if (!this.looksEncrypted(v)) {
      const re = await this.encrypt(v);
      await this.prefs!.put('apiKey', re);
      await this.prefs!.flush();
      return v;
    }
    return await this.decrypt(v);
  }

  // encrypt / decrypt / looksEncrypted 实现见 @kit.UniversalKeystoreKit 文档
}
```

### 关键约束
- HUKS key 命名版本化（`v1` / `v2`）—— 算法升级时不破坏老数据
- **一次迁移**：检测历史明文，下次写入时透明加密
- 不要在日志打 `apiKey`（即使脱敏也别打），见 `SEC-002`

## 七、OHPM 仓库 502 兜底

### 现象
`ohpm install` 报 502 / 网络 timeout，可能上游临时故障，build 阻塞。

### 兜底方案

```bash
# 1. 临时注释 devDependencies 让 build 通过（生产依赖留着）
# 编辑 oh-package.json5：把不阻塞构建的 devDependencies 注释掉

# 2. 切镜像
ohpm config set registry https://ohpm.openharmony.cn/ohpm/

# 3. 用本地缓存（如果之前装过）
ohpm install --offline

# 4. 实在不通：直接 hvigorw assembleHap，OHPM 仓库 502 不阻塞构建（已装的依赖仍可用）
```

## 八、终端 hvigorw 需 DEVECO_SDK_HOME

### 现象
DevEco IDE 内 build 正常；终端跑 `hvigorw assembleHap` 报 "DEVECO_SDK_HOME not set"。

### 解决

```bash
# 一次性写到 ~/.zshrc（推荐）
echo 'export DEVECO_SDK_HOME=$HOME/Library/Huawei/Sdk' >> ~/.zshrc
source ~/.zshrc

# 或单次：
DEVECO_SDK_HOME=$HOME/Library/Huawei/Sdk hvigorw assembleHap
```

> 本仓库的 `tools/install-deveco-prereqs.sh` 第 6 节会自动配。

## 九、@kit.AbilityKit 命名空间易混

### 现象

`Configuration` 类型（用作 `onConfigurationUpdate(newConfig: ...)` 的参数类型）**直接从 `@kit.AbilityKit` 顶层导出**，**不在** `ConfigurationConstant` 命名空间下。AI 训练数据里常把它误归到 `ConfigurationConstant` 下，编译器会报：

```
Namespace 'ConfigurationConstant' has no exported member 'Configuration'.
```

```typescript
// ❌ AI 习惯误写（误以为 Configuration 在 ConfigurationConstant 命名空间下）
import { ConfigurationConstant } from '@kit.AbilityKit';
onConfigurationUpdate(newConfig: ConfigurationConstant.Configuration): void { /* ... */ }

// ✅ 正确：Configuration 直接从 @kit.AbilityKit 顶层导入
import { Configuration } from '@kit.AbilityKit';
onConfigurationUpdate(newConfig: Configuration): void { /* ... */ }

// ConfigurationConstant 是另一回事——它是常量类，用于枚举值访问：
import { ConfigurationConstant } from '@kit.AbilityKit';
const dir = ConfigurationConstant.Direction.DIRECTION_VERTICAL;
```

### 常用 Kit 类型 import 速查（v0.5 实战补充）

| 想用类型 | 应该 import 自 | 备注 |
| --- | --- | --- |
| `Configuration`（配置变更回调参数） | `@kit.AbilityKit`（顶层） | ⚠️ 不在 `ConfigurationConstant` 命名空间 |
| `ConfigurationConstant.*`（配置常量） | `@kit.AbilityKit` | 用于 `ConfigurationConstant.Direction.DIRECTION_VERTICAL` 这种枚举值 |
| `BusinessError` | `@kit.BasicServicesKit` | 鸿蒙 Promise 拒绝错误的标准类型 |
| `Want` / `UIAbility` / `AbilityConstant` | `@kit.AbilityKit` | |
| `Permissions`（权限名字面量类型） | `@kit.AbilityKit` | 不是普通 string，是字面量联合 |
| `abilityAccessCtrl.AtManager` | `@kit.AbilityKit` | 权限授予 |
| `webview.WebviewController` / `WebController` | `@kit.ArkWeb` | Web 组件控制器 |
| `mediaquery.MediaQueryListener` | `@kit.ArkUI` | 主题 / 断点监听 |
| `preferences.Preferences` | `@kit.ArkData` | KV 存储 |
| `relationalStore.RdbStore` / `ResultSet` | `@kit.ArkData` | RDB |
| `request.UploadConfig` | `@kit.BasicServicesKit` | 文件上传（不是 @kit.NetworkKit） |
| `huks.HuksOptions` | `@kit.UniversalKeystoreKit` | HUKS 加密 |

### 真踩坑示例

```typescript
// ❌ 实战中常见错误
onConfigurationUpdate(newConfig: ConfigurationConstant.Configuration): void { /* ... */ }
//                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//   ConfigurationConstant 没有 Configuration 类型，IDE 可能不立即报红但运行时崩

// ✅ 正确
import { Configuration } from '@kit.AbilityKit';
onConfigurationUpdate(newConfig: Configuration): void { /* ... */ }
```

不确定？**Ctrl+点进类型定义**或在 `upstream-docs/.../reference/apis-ability-kit/` 搜。

## 十、NavPathStack.pop() 到空 stack → 白屏

### 现象
用户点 close / back 按钮后页面变白；hilog 看不到 crash，只是 `Navigation` 没有 `NavDestination` 可显示。

### 原因
`NavPathStack.pop()` 是无条件出栈。如果 stack 只剩一层（最常见：Splash 用 `replacePathByName` 替换了自己，目标页是栈底），pop 后 stack 为空 → Navigation 无内容 → 白屏。

### 反模式
```typescript
// ❌ Splash → replacePathByName('open-project') 让 open-project 是 stack 唯一项
// 然后 open-project 的 X 按钮：
Text('x').onClick(() => this.pathStack?.pop())   // ← stack 空 → 白屏
```

### 正确写法
所有 `pop` 调用必须先判空：
```typescript
private handleCloseClick(): void {
  if (this.pathStack === null) return;
  if (this.pathStack.size() > 1) {
    this.pathStack.pop();
    return;
  }
  // 已经是栈底：跳到一个"安全的回退页"而非 pop 到空
  try {
    this.pathStack.replacePathByName('welcome', JSON.parse('{}') as Object, false);
  } catch (e) {
    this.pathStack.pushPath({ name: 'welcome' }, false);
  }
}
```

### 教训
- `Splash → replacePathByName(主页)` 是标准模式（让 Splash 自身从 stack 消失，防 back 死循环），但**所有目标页**都要假设自己可能是栈底。
- 关闭按钮 / 返回手势的 pop 必须做 `size() > 1` guard。
- 物理返回键由系统处理，按需 `BackHandler` 拦截 — 鸿蒙没有自动 "exit app on empty stack" 兜底。

## 十一、ArkUI emoji / Unicode 高码位字符渲染不可靠

### 现象
设计稿写 `Button('⌕')` / `Text('🎙')` / `Text('⋯')`，编译过、APK 装上后真机显示成乱码方框或 fallback 字符（"c" / "I" / "."）。

### 原因
鸿蒙系统字体（HarmonyOS Sans）对 Unicode 覆盖**有限**：
- ✅ 必支持：ASCII / Latin-1 / CJK 中文 / 部分 BMP 基本符号（`≡` `·` `→` `↓` `×` `✓` `>`）
- ❌ 不支持：大多数 emoji（U+1F300+）、Misc Technical Symbols 部分（`⌕` U+2315、`▣` U+25A3、`⌬` U+232C、`⋯` U+22EF）、emoji presentation selector

实测真机 Mate 70 Pro (HarmonyOS 6.1) 上 `⚙` U+2699（齿轮）可显示，`🖥️` U+1F5A5（显示器）显示空白方框。

### 正确策略
**优先级**：ASCII 文字标签 > 中文单字 > BMP 基础符号 > 自带 SymbolGlyph (sys.symbol.*) > emoji。

```typescript
// ❌ 字体不支持 → 显示成方框 / fallback 错字符
Button('🔍')   // search
Button('📁')   // files
Button('⋯')    // more (U+22EF)

// ✅ ASCII / 中文 / BMP 基本符号 — 必显示
Button('搜')   // 中文单字
Text('...')    // 3 个 ASCII period
Text('≡')      // U+2261 三横（menu）
Text('+')      // ASCII
Text('·')      // U+00B7 中点（list bullet）
Text('×')      // U+00D7（close button）
```

### 验证流程
不确定 emoji / Unicode 是否可显示？**在写代码前先用 Bash 写最小 .ets 测试 + 真机截图**，不要假设 lucide-react 等 Web 图标库的字符鸿蒙也有。

### 进一步：图标方案对比

| 方案 | 优点 | 缺点 |
| --- | --- | --- |
| Text + ASCII / 中文 | 必显示、轻量、无资源 | 视觉简陋 |
| SymbolGlyph + `sys.symbol.*` | 系统原生 icon font | 需 HarmonyOS 5+；不是所有 lucide 都有对应 sys.symbol |
| Image + rawfile SVG | 视觉完全可控 | 需自备 SVG asset；包体增加 |

`scan-arkts.sh` 后续可加 `UI-001` 规则检测 `Button|Text\('[非ASCII非CJK字符]'\)` 给警告（v0.4 候选）。

## 十二、ArkUI Button width 限定 + 多字符文本被默认 padding 截断

### 现象
```typescript
Button('Git')          // 期望 "Git" 3 字符
  .fontSize(FontSize.xs)
  .width(40)
```
真机显示 `'..'` —— 文本被 ellipsis 截断了。

### 原因
ArkUI Button 有默认 horizontal padding (~16px 左右两侧)。`width(40)` 减去 32px padding 后**文本可用区只剩 ~8px**，连 3 个 ASCII 字符都放不下。

### 正确写法（首选）
对 small icon 按钮，**用 `Text` + `.onClick` 替代 `Button`**：
- `Text` 无 default padding，`width` 真实可用
- 视觉更轻量
- a11y 用 `.accessibilityText` 显式声明语义

```typescript
// ❌ Button 限 width 后多字符截断
Button('Git').width(40)
Button('...').width(40)

// ✅ Text + onClick — 无 default padding
Text('Git')
  .fontSize(FontSize.base)
  .fontColor(this.colors.foreground)
  .width(44).height(44)
  .textAlign(TextAlign.Center)
  .accessibilityText('Git panel')
  .onClick(() => { /* ... */ })
```

### 备选
若必须用 `Button`，要么去 default padding，要么放大 width：
```typescript
Button('Git')
  .padding({ left: 4, right: 4 })   // 缩 padding
  .width(60)                        // 或加大 width
```

## 十三、ArkUI build() 必须单 root container

### 现象
编译报错：
```
In an '@Entry' decorated component, the 'build' method can have only one root node, which must be a container component.
```

### 原因
ArkUI 硬约束：`build()` 顶层必须**恰好一个**容器组件（Column / Row / Stack / Flex / Grid / List 等）。

不能写：
```typescript
// ❌ build 内有多个顶层语句
build() {
  if (this.style === 'center') {
    this.centerBlock()         // ← 多分支，每个分支顶层不同
  }
  Row() { this.alignedColumn() }
}
```

### 正确写法
**所有分支 wrap 进单一外层容器**：
```typescript
build() {
  Column() {
    if (this.style === 'center') {
      this.centerBlock()
    } else {
      Row() { this.alignedColumn() }
    }
  }
  .width('100%')
}
```

### 注意
- `@Builder` 子函数不受限（可以多顶层）—— 限制只针对 `build()`
- 错误信息有时指向行号偏移，找最近的 `if` / `switch` / 早期 `return` 即可定位

## 十四、Workspace timeline timestamp 不显示 — 路径绕过了 reducer

### 现象
打开历史会话后用户/助手消息没有时间戳（agent_stream 实时流入的消息有，但 resume 后历史那段没有）。

### 原因
鸿蒙端 timeline 有两条数据路径：
- **路径 1（流推）** `agent_stream` event → `TimelineReducer.apply` → 转发 timeline item
- **路径 2（历史拉取）** `fetch_agent_timeline_response` → 应走 `TimelineReducer.applyFetchedEntries`

`applyFetchedEntries` 内部对每个 entry 调 `injectTimestamp(item, ts)`（把 entry.timestamp ISO 转 epoch ms 写到 item.timestamp）。**如果绕过 reducer 直接调 `SessionStore.appendTimelineItem`，timestamp 注入这步被跳过 → UI 拿不到时间戳**。

### 反模式
```typescript
// ❌ Workspace.resumeExistingAgent 直接 append (绕过 reducer)
const payload = await client.fetchAgentTimeline({ agentId });
for (let i = 0; i < payload.entries.length; i++) {
  this.session.appendTimelineItem(agentId, payload.entries[i].item);
  //                                          ^ 跳过 injectTimestamp
}
```

### 正确写法
**所有 timeline 写入必须经过 reducer**：
```typescript
// ✅
const payload = await client.fetchAgentTimeline({ agentId });
this.reducer.applyFetchedEntries(agentId, payload.entries);
//           ^ 内部循环每条 entry 调 injectTimestamp 再 append
```

### 教训
- 状态管理层应**封死**直接修改 store 的入口；所有更新走 reducer / action 函数。
- review 时凡是看到 `session.append*` 直接调用，先质疑是否绕过了 reducer。

## 十五、Per-host store 必须按 serverId 隔离

### 现象
同账号添加 2 个 host（mac 本机 + 公司机），切 host 时上一个 host 的 git/checkout/agent/draft 状态泄漏到另一个 host。

### 原因
单例 store 用 `cwd` 或 `agentId` 单 key 分桶 → 两 host 上恰好同 cwd（如 `/tmp` 或 `~/project`）时会**互相覆盖**。

### 正确模式（强制约定）
所有 per-host store 的 key **必须**形如 `${serverId}:${...}`：

| Store | key |
| --- | --- |
| `DraftStore` | `${serverId}:${agentId}` |
| `AttachmentStore` | `${serverId}:${agentId}` |
| `CheckoutStore` | `${serverId}:${cwd}` |
| `WorkspaceTabsStore` | `${serverId}:${workspaceId}` |
| `ProviderSnapshotStore` | `${serverId}` |
| `TerminalManager` | 每 host 单独实例（per `HostRuntimeController`） |

### 自动化
新增 store 时在 PR 描述对照这个表 + 加单元测试（不同 serverId 同 cwd 不互相干扰）。

## 十六、daemon `agent.workspaceId` 不可靠 — 必须 cwd fallback 匹配

### 现象
点 sessions 列表的 workspace card → 进入会话页显示 "Create new agent" 表单，明明该 workspace 之前有过会话。

### 原因
`fetch_agents_response.entries[].agent` 的 `workspaceId` 字段在某些 daemon 版本 / workspace 类型下可能：
- 是 `undefined`
- 是 path 字符串（不是 uuid）
- 与 `fetch_workspaces_response.entries[].id` 不严格相等

直接按 `agent.workspaceId === ws.workspaceId` 严格匹配会漏掉大批 agent。

### 正确模式：三层匹配 fallback
```typescript
function findWorkspaceForAgent(
  agent: AgentSnapshot,
  workspaces: WorkspaceEntry[],
): WorkspaceEntry | null {
  // 1. 严格 workspaceId 匹配
  const wid = agent.workspaceId;
  if (wid !== undefined && wid !== '') {
    const ws = workspaces.find(w => w.workspaceId === wid);
    if (ws !== undefined) return ws;
  }
  // 2. cwd 匹配 workspaceDirectory / projectRootPath
  if (agent.cwd !== '') {
    const ws = workspaces.find(w => {
      const wsDir = w.workspaceDirectory ?? w.projectRootPath ?? '';
      return wsDir !== '' && wsDir === agent.cwd;
    });
    if (ws !== undefined) return ws;
  }
  return null;
}
```

### 教训
- daemon 返回的"应该是 uuid"的字段在多种 workspace 类型（directory / worktree / local_checkout）下可能填 path —— 永远做 cwd fallback。
- 上游 schema 字段名细节（如 `id` vs `workspaceId`）必须按真实 wire-format 而非 client 内部 normalize 后的名字对照。

## 十七、应用图标 layered icon · 三处资源 + foreground 必须真透明

### 现象
替换 app 桌面图标后，桌面渲染出来是**新图标与旧默认图标的叠加**——比如新图是"对话气泡 + 锁"，但锁的轮廓里能隐约看到 DevEco 默认 startIcon 的"四方格"幽灵图案。

### 原因
HarmonyOS 6 桌面强制走 layered icon（`module.json5` / `AppScope/app.json5` 里 `icon: "$media:layered_image"`）。layered icon 由 **background.png + foreground.png 两层叠加**，且资源**在两个 scope 都有一份**：

```
AppScope/resources/base/media/{background,foreground}.png        ← 应用级（全局/AppGallery）
products/<name>/src/main/resources/base/media/{background,foreground}.png  ← product 级（覆盖应用级）
```

AI 经常只换 product 那一份，AppScope 还是旧的；或只换 `background.png` 不动 `foreground.png`。

**真正的坑在 foreground.png**：DevEco 工程模板生成的默认 `foreground.png` 看起来是空白图——**但它不是真透明**，而是「半透明白色四方格」（RGB=255, alpha≈128–230 之间）。Read 工具 / 预览肉眼看是纯白，必须读像素才能发现：

```bash
python3 -c "
from PIL import Image
im = Image.open('foreground.png').convert('RGBA')
nz = sum(1 for p in im.get_flattened_data() if p[3] != 0)
print(f'non-zero alpha pixels: {nz}/{im.width*im.height}')
"
# 默认模板输出类似：non-zero alpha pixels: 394373/1048576 (37.6%)
```

只换 background 不重写 foreground → 桌面叠加显示 = 新背景 + 半透明白色四方格 → **幽灵图案**。

### 正确写法

**完整图标内容（含底色方形）放 `background.png` 1024×1024；`foreground.png` 必须重新生成为真透明 PNG**。桌面会自动加圆角 mask。

```bash
# 1) 源 icon 缩到 1024×1024 → 覆盖两处 background.png
sips -z 1024 1024 source-icon.png --out /tmp/bg.png
cp /tmp/bg.png AppScope/resources/base/media/background.png
cp /tmp/bg.png products/<name>/src/main/resources/base/media/background.png

# 2) 真透明 foreground.png（alpha=0）覆盖两处
python3 -c "
from PIL import Image
img = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
for p in [
    'AppScope/resources/base/media/foreground.png',
    'products/<name>/src/main/resources/base/media/foreground.png',
]: img.save(p)
"

# 3) startIcon（启动窗口图，不参与 layered）：sips 缩 256×256 → products 一处即可
sips -z 256 256 source-icon.png --out products/<name>/src/main/resources/base/media/startIcon.png
```

### 验证

```bash
# foreground 必须 0 个非零 alpha 像素
python3 -c "
from PIL import Image
for p in ['AppScope/.../foreground.png','products/.../foreground.png']:
    im = Image.open(p).convert('RGBA')
    nz = sum(1 for px in im.get_flattened_data() if px[3] != 0)
    assert nz == 0, f'{p} still has {nz} non-transparent pixels'
"
```

### 反模式
```bash
# ❌ 只换 product，AppScope 还是旧图 → AppGallery / 任务管理器图标错版
# ❌ 只换 background，foreground 用模板默认 → 桌面叠加显示幽灵图案
# ❌ 把整图塞进 foreground（想着 layered icon 的"前景"= 主体）→ HarmonyOS 桌面会把 foreground 缩到 60% 安全区显示，结果是"图标里的图标"
```

### 桌面缓存
换完装机后桌面图标仍是旧的：HarmonyOS 桌面会缓存 layered icon 渲染结果。`hdc shell aa force-stop com.huawei.hmos.huawei.launcher` 或重启可清缓存；AppGallery 图标可能 24h 内才刷新。

## 进一步参考

- 实战 case study：[`docs/case-studies/llm-chat-app.md`](../../../docs/case-studies/llm-chat-app.md)
- Android parity 迁移 case study：[`docs/case-studies/android-parity-migration.md`](../../../docs/case-studies/android-parity-migration.md)
- 多模态 LLM 专项：[`multimodal-llm`](../multimodal-llm/SKILL.md)
- Web 嵌入专项：[`web-bridge`](../web-bridge/SKILL.md)
- AGC 提审拒因：[`07-publishing/checklist-2026-rejection-top20.md`](../../../07-publishing/checklist-2026-rejection-top20.md)
