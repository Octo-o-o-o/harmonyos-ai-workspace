# Quick Reference · 快速速查

一组高密度的备忘表，开发时随手翻。

## 1. ArkTS 装饰器一览

### UI 装饰器

```typescript
@Entry           // 页面入口（每个页面唯一）
@Component       // 组件（V1）
@ComponentV2     // 组件（V2，状态系统升级）
@Builder         // 可复用 UI 函数
@BuilderParam    // 子组件 UI 槽位
@Styles          // 复用样式
@Extend(Cmp)     // 扩展指定组件样式
@CustomDialog    // 自定义弹窗
@Preview         // IDE 实时预览
@Reusable        // 池化复用
@AnimatableExtend // 可动画属性扩展
@Concurrent      // TaskPool 并发函数
```

### 状态装饰器（V1）

```typescript
@State name: string = ''                   // 私有
@Prop name: string                         // 父→子，单向
@Link name: string                         // 父↔子，双向 (传 $$xxx)
@Provide name: string = ''                 // 跨层级提供
@Consume name: string                      // 跨层级订阅
@Observed class Foo {}                     // 引用类型
@ObjectLink foo: Foo                       // 接收 @Observed 类
@StorageProp('key') v: string = ''         // 全局 AppStorage 单向
@StorageLink('key') v: string = ''         // 全局 AppStorage 双向
@LocalStorageProp / @LocalStorageLink      // 页面级
@Watch('cb') v: number                     // 变化回调
@Track field: string                       // V1 类字段精确订阅
```

### 状态装饰器（V2）

```typescript
@ComponentV2
struct ... {
  @Local x: number = 0;             // 类似 @State
  @Param y: number = 0;             // 类似 @Prop（不可变）
  @Once @Param z: number = 0;       // 仅初始化一次
  @Event onTap: () => void;         // 子→父事件
  @Provider() global: string = '';
  @Consumer() global: string = '';
  @Computed get total(): number { return this.x + this.y; }
  @Monitor('x') onXChanged() {}
}

@ObservedV2
class Model {
  @Trace value: number = 0;
}
```

## 2. 组件链式属性常用

### 通用

```typescript
.width('100%' | 100 | 100vp)
.height(100)
.margin(10)
.margin({ left: 10, right: 10, top: 8, bottom: 8 })
.padding(8)
.backgroundColor(Color.White | '#FFF' | $r('sys.color.x'))
.borderRadius(8)
.border({ width: 1, color: Color.Gray, style: BorderStyle.Solid })
.shadow({ radius: 4, color: '#0001' })
.opacity(0.5)
.visibility(Visibility.Hidden | Visible | None)
.position({ x: 10, y: 20 })
.offset({ x: 10, y: 20 })
.rotate({ angle: 45 })
.scale({ x: 1.2, y: 1.2 })
.translate({ x: 10 })
.zIndex(10)
.onClick((event) => {})
.onTouch((e) => {})
.gesture(LongPressGesture().onAction((e) => {}))
.animation({ duration: 300, curve: Curve.EaseInOut })
```

### Text

```typescript
Text('hello')
  .fontSize(16)
  .fontWeight(FontWeight.Bold)
  .fontColor(Color.Black)
  .textAlign(TextAlign.Center)
  .maxLines(2)
  .textOverflow({ overflow: TextOverflow.Ellipsis })
  .lineHeight(24)
  .decoration({ type: TextDecorationType.Underline })
```

### Image

```typescript
Image($r('app.media.icon'))
  .width(100)
  .height(100)
  .objectFit(ImageFit.Cover)
  .borderRadius(50)
  .interpolation(ImageInterpolation.High)
  .alt($r('app.media.placeholder'))
```

### Button

```typescript
Button('OK', { type: ButtonType.Capsule, stateEffect: true })
  .width('80%')
  .height(40)
  .backgroundColor($r('sys.color.ohos_id_color_primary'))
  .onClick(() => { /* */ })
```

## 3. 资源引用

```typescript
$r('app.string.app_name')        // string.json
$r('app.color.primary')          // color.json
$r('app.media.icon')             // media/*.png|jpg|svg
$r('app.float.dimen')            // float.json
$rawfile('config.json')          // rawfile/*
$r('sys.color.ohos_id_color_x')  // 系统色
$r('sys.string.ohos_app_x')      // 系统字符串
```

## 4. 路径与文件

```
AppScope/app.json5                   ← 全局 bundle / version / icon
entry/src/main/module.json5          ← module / abilities / permissions
entry/src/main/ets/                  ← 源码
entry/src/main/resources/base/       ← 默认资源
entry/src/main/resources/zh_CN/      ← 中文
entry/src/main/resources/en_US/      ← 英文
entry/src/main/resources/dark/       ← 暗色
entry/src/main/resources/rawfile/    ← 原始资源
entry/build-profile.json5            ← 模块构建
build-profile.json5                  ← 工程构建
oh-package.json5                     ← 依赖
hvigorfile.ts                        ← 构建脚本
code-linter.json5                    ← 代码规则
obfuscation-rules.txt                ← 混淆规则
```

## 5. CLI 命令汇总

### Hvigor

```bash
hvigorw --sync                          # 同步
hvigorw clean
hvigorw assembleHap -p buildMode=debug
hvigorw assembleApp -p buildMode=release
hvigorw test
hvigorw codeLinter
hvigorw tasks --all
hvigorw :entry:assembleHap
```

### OHPM

```bash
ohpm install
ohpm install <pkg>
ohpm install --save-dev <pkg>
ohpm uninstall <pkg>
ohpm update [pkg]
ohpm list
ohpm config set registry https://ohpm.openharmony.cn/ohpm/
```

### hdc

```bash
hdc list targets
hdc -t <id> install -r app.hap
hdc shell aa start -a EntryAbility -b com.example.x
hdc shell aa force-stop com.example.x
hdc hilog | grep tag
hdc hilog -L D|I|W|E
hdc shell snapshot_display -f /data/local/tmp/s.png
hdc file recv /data/local/tmp/s.png ./
hdc fport tcp:9229 tcp:9229
```

## 6. 生命周期

### UIAbility

```
onCreate            创建实例（启动）
onWindowStageCreate 主窗口创建后绑定 UI
onForeground        进入前台
onBackground        退到后台
onWindowStageDestroy 窗口销毁
onDestroy           实例销毁
```

### Page (Component with @Entry)

```
aboutToAppear()     创建之前
onPageShow()        页面显示
onBackPress()       返回键拦截
onPageHide()        页面隐藏
aboutToDisappear()  销毁之前
```

### Component (普通)

```
aboutToAppear()
build()             首次/状态变化时执行
aboutToDisappear()
```

### Component (V2)

```
aboutToAppear()
aboutToDisappear()
onWillApplyTheme(theme)
```

## 7. 路由（旧 router API）

```typescript
import { router } from '@kit.ArkUI';

router.pushUrl({ url: 'pages/Detail', params: { id: 1 } });
router.replaceUrl({ url: 'pages/Login' });
router.back();
router.clear();
```

`pages` 路由表：`entry/src/main/resources/base/profile/main_pages.json`

```json
{ "src": ["pages/Index", "pages/Detail"] }
```

## 8. 单位

- **vp**：virtual pixel，跨设备一致（1 vp ≈ 1 dp Android）
- **fp**：font px，自动缩放跟随用户字号
- **px**：物理像素（少用）
- **lpx**：逻辑像素，按设计稿宽度计算
- 百分比：`'50%'`

## 9. 颜色 token（系统）

```
sys.color.ohos_id_color_primary
sys.color.ohos_id_color_secondary
sys.color.ohos_id_color_text_primary
sys.color.ohos_id_color_text_secondary
sys.color.ohos_id_color_text_hint
sys.color.ohos_id_color_warning
sys.color.ohos_id_color_alert
sys.color.ohos_id_color_background
sys.color.ohos_id_color_foreground
sys.color.ohos_id_color_focused_outline
```

## 10. 常用 import

```typescript
// Ability / 权限
import { UIAbility, AbilityConstant, Want, common, abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

// 路由 / 导航
import { router } from '@kit.ArkUI';

// 网络
import { http, socket, webSocket } from '@kit.NetworkKit';

// 文件
import { fileIo as fs, picker } from '@kit.CoreFileKit';

// 数据
import { preferences, relationalStore } from '@kit.ArkData';

// 媒体
import { media } from '@kit.MediaKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';

// 日志 / 性能
import { hilog, hiTraceMeter } from '@kit.PerformanceAnalysisKit';

// 异常
import { BusinessError } from '@kit.BasicServicesKit';

// ArkTS 工具
import { taskpool, worker } from '@kit.ArkTS';
import { JSON } from '@kit.ArkTS';                   // 优于 globalThis.JSON
import { util, ArrayList, HashMap, HashSet } from '@kit.ArkTS';
```

## 11. ArkUI 常见容器对照

| ArkUI | Web/CSS 类比 |
| --- | --- |
| `Column()` | `flex-direction: column` |
| `Row()` | `flex-direction: row` |
| `Stack()` | `position: absolute` 层叠 |
| `Flex()` | `display: flex` 完整版 |
| `Grid` | `display: grid` |
| `RelativeContainer` | `position: relative` 相对约束 |

## 12. 常见错误码

| 码 | 含义 |
| --- | --- |
| 201 | 权限被拒（PERMISSION_DENIED） |
| 202 | 非系统应用调用系统 API |
| 401 | 参数错误 |
| 801 | 设备不支持该能力 |
| 16000050 | Ability 启动错误 |
| 9568305 | HAP 安装包过大 / 校验失败 |

## 13. 性能体检命令

```bash
hdc shell hidumper -s RenderService -a fps         # FPS
hdc shell hidumper -s WindowManagerService -a -a   # 窗口
hdc shell hidumper -s 10                           # 内存
hdc shell hidumper -s SAMgr                        # 系统服务
```

## 14. 调试 Tips

- 开启慢动画：`hdc shell setprop debug.graphic.frame_rate 30`
- 显示布局边界：DevEco Inspector → 切换 "Show Layout Bounds"
- HiLog tag 过滤：`hilog.info(0x1234, 'MyApp', '%{public}s', value)`，过滤 `hdc hilog | grep MyApp`
- WebView 调试：`web_webview.setWebDebuggingAccess(true)`，然后 Chrome `chrome://inspect`
