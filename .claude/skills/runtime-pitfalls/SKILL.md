---
name: runtime-pitfalls
verified_against: harmonyos-6.0.2-api22  # last sync 2026-05-07
description: |
  鸿蒙工程**运行时装配陷阱**——ArkTS 语法无错但项目跑不起来 / 行为不正确的工程层坑。
  来源：真实 LLM 对话客户端 app 的 M3-M12 实战反馈。
  **激活条件**（满足任一即激活）：
    - 修改 `build-profile.json5` / `module.json5` / `oh-package.json5` 任意一个
    - 改 `resources/*/element/string.json` 或其他资源文件
    - 实现主题切换 / 跟随系统外观（涉及 `@StorageLink('appearanceTheme')`）
    - 在 Web 组件上注册 `javaScriptProxy` / 实现 H5 ↔ ArkTS 桥
    - 写多模态 LLM 调用（OpenAI Vision / Whisper / DALL-E 等）
    - 多模块工程（feature 拆分）+ 模块改名
    - HUKS 加密集成（API key / 用户敏感数据落盘）
  **不激活**：纯 UI 组件、纯算法逻辑、单 module hello world。
---

# 鸿蒙运行时装配陷阱

> 触发场景：**ArkTS 编译能过但 app 跑不起来 / 行为不对**。这一层 grep 扫不出来，靠 AI 主动避免。
>
> 来源：真实 LLM 对话 app 的 M3-M12 工程踩坑总结。

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
```typescript
// ❌ 错的：Configuration 不在 @kit.AbilityKit 顶层
import { Configuration } from '@kit.AbilityKit';

// ✅ 对的：在 ConfigurationConstant 命名空间下
import { ConfigurationConstant } from '@kit.AbilityKit';
const orientation = ConfigurationConstant.Direction.DIRECTION_VERTICAL;
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

## 进一步参考

- 实战 case study：[`docs/case-studies/llm-chat-app.md`](../../../docs/case-studies/llm-chat-app.md)
- 多模态 LLM 专项：[`multimodal-llm`](../multimodal-llm/SKILL.md)
- Web 嵌入专项：[`web-bridge`](../web-bridge/SKILL.md)
- AGC 提审拒因：[`07-publishing/checklist-2026-rejection-top20.md`](../../../07-publishing/checklist-2026-rejection-top20.md)
