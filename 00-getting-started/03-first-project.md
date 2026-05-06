# 创建第一个 HarmonyOS 应用

## 1. 在 IDE 中创建

1. 启动 DevEco Studio
2. **File → New → Create Project**
3. 模板选择：**Application → Empty Ability**（推荐起步）
4. 配置：
   - **Project name**: `HelloHarmony`
   - **Bundle name**: `com.example.helloharmony`（反向域名，会写入 `app.json5`）
   - **Save location**: `~/WorkSpace/HarmonyOS_DevSpace/samples/hello-harmony/`
   - **Compile SDK**: API 21（默认推荐，消费稳定版）；如需 6.0.2 新能力可上 API 22
   - **Model**: **Stage**（必选；FA 已废弃）
   - **Language**: **ArkTS**
   - **Device type**: 勾选 Phone / Tablet
5. 点 **Finish**，等待 Hvigor 同步

## 2. 项目结构解读

```
hello-harmony/
├── AppScope/
│   ├── app.json5                    ← 应用全局配置（bundleName / version / icon）
│   └── resources/
├── entry/                           ← 默认 Entry HAP 模块
│   ├── build-profile.json5          ← 模块编译配置
│   ├── hvigorfile.ts                ← 构建任务定义
│   ├── obfuscation-rules.txt        ← 代码混淆规则
│   ├── oh-package.json5             ← 模块依赖
│   └── src/
│       ├── main/
│       │   ├── ets/
│       │   │   ├── entryability/
│       │   │   │   └── EntryAbility.ets
│       │   │   ├── entrybackupability/
│       │   │   │   └── EntryBackupAbility.ets
│       │   │   └── pages/
│       │   │       └── Index.ets
│       │   ├── resources/
│       │   │   ├── base/
│       │   │   │   ├── element/         ← 字符串、颜色资源
│       │   │   │   ├── media/           ← 图片
│       │   │   │   └── profile/
│       │   │   ├── en_US/
│       │   │   ├── zh_CN/
│       │   │   └── rawfile/
│       │   └── module.json5         ← 模块配置（abilities / permissions / metadata）
│       ├── ohosTest/                ← UI Test
│       └── test/                    ← Unit Test
├── build-profile.json5              ← 工程级构建配置
├── code-linter.json5
├── hvigorfile.ts
└── oh-package.json5                 ← 工程级依赖
```

## 3. 入口文件解读

### `entry/src/main/ets/entryability/EntryAbility.ets`

```typescript
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load content. %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading content.');
    });
  }
}
```

### `entry/src/main/ets/pages/Index.ets`

```typescript
@Entry
@Component
struct Index {
  @State message: string = 'Hello HarmonyOS';

  build() {
    Column() {
      Text(this.message)
        .fontSize(40)
        .fontWeight(FontWeight.Bold)
        .onClick(() => {
          this.message = 'Welcome to ArkTS!';
        })
    }
    .height('100%')
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }
}
```

要点：
- `@Entry` 标记入口组件，每个页面只能有一个
- `@Component` 标记 ArkUI 组件
- `@State` 声明状态变量，变更会触发重渲染
- `build()` 方法描述 UI 树
- 链式调用 `.fontSize()` `.onClick()` 是 ArkUI 的属性 / 事件 API

## 4. 在模拟器或真机上运行

### 模拟器（推荐起步）

1. **Tools → Device Manager**
2. 选 Phone 模板，API 21（或 22），启动
3. 工具栏选中模拟器，点绿色 ▶ Run
4. 首次运行 Hvigor 会构建 HAP，约 30-60 秒

### 真机（需要调试证书）

1. 用数据线连接华为设备，开启「USB 调试」
2. **File → Project Structure → Signing Configs**
3. 勾选 "Automatically generate signature" → Sign In 华为账号
4. IDE 自动生成 `.p12`、`.csr`、调试 profile
5. 点 ▶ Run

> 自动签名仅用于 **调试**，发布需要手动配置 release 签名，详见 [`04-signing-and-publishing.md`](04-signing-and-publishing.md)。

## 5. 命令行构建（可选）

```bash
cd samples/hello-harmony

# 安装依赖
ohpm install

# 构建 debug HAP
hvigorw assembleHap --mode module -p product=default -p buildMode=debug

# 构建 release App 包（需要签名配置）
hvigorw assembleApp --mode project -p product=default -p buildMode=release

# 产物位置
ls entry/build/default/outputs/default/*.hap
```

## 6. 安装与启动

```bash
# 列出已连接设备
hdc list targets

# 安装到设备
hdc install entry/build/default/outputs/default/entry-default-signed.hap

# 启动应用
hdc shell aa start -a EntryAbility -b com.example.helloharmony

# 查看日志（类似 logcat）
hdc hilog | grep testTag
```

## 7. 修改与热更新

DevEco Studio 6.x 支持 **HotReload**（保存文件即重载 UI），不需要重新部署整个 HAP。开关：**Run → Edit Configurations → Enable HotReload**。

## 8. 第二步学什么

| 你想 | 看哪里 |
| --- | --- |
| 学 ArkTS 语法 | [`../01-language-arkts/`](../01-language-arkts/) |
| 添加更多页面 / 路由 | [`../02-framework-arkui/01-routing.md`](../02-framework-arkui/01-routing.md) |
| 调用网络 / 存储 / 媒体 | [`../03-platform-apis/`](../03-platform-apis/) |
| 多模块组织代码 | `upstream-docs/.../quick-start/in-app-hsp.md` |
| 适配平板 / 折叠屏 | [`../05-best-practices/02-multi-device.md`](../05-best-practices/) |

## 9. 调试技巧

- **HiLog**：用 `hilog.info(DOMAIN, 'tag', 'fmt %{public}s', value)`，DevEco 的 Log 面板可过滤
- **Inspector**：Run 时点 **View → Tool Windows → ArkUI Inspector**，查看组件树
- **Profiler**：**View → Tool Windows → Profiler**，CPU / Memory / Frame
- **断点**：在 `.ets` 文件行号左侧点击，IDE 会停在断点

## 10. 参考

- 官方 ArkTS 入门：`upstream-docs/openharmony-docs/zh-cn/application-dev/quick-start/arkts-get-started.md`
- 项目结构：`upstream-docs/openharmony-docs/zh-cn/application-dev/quick-start/application-package-structure-stage.md`
- Stage 模型：`upstream-docs/openharmony-docs/zh-cn/application-dev/application-models/stage-model-development-overview.md`
