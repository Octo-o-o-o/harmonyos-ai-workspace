# 最佳实践 · Performance / Multi-Device / Security

汇总 HarmonyOS 应用开发中常见的工程实践要点，每节末尾给出本地权威文档路径。

## 1. 性能优化

### 1.1 启动速度

- **冷启动 < 500ms** 是良好基线。优化方向：
  - 缩减 `EntryAbility.onCreate` 中的同步任务，移到 `onWindowStageCreate` 之后异步执行
  - 用 `ohos.app.startupTask`（`startup_config.json`）声明并行的启动任务
  - `XComponent`、Web、地图等重组件延迟初始化
  - 减少 import：尽量按需 `import { http } from '@kit.NetworkKit'`，不要 `import * as ...`

- 详见：`upstream-docs/.../performance/improve-application-launch-speed.md`

### 1.2 渲染性能

- 用 **LazyForEach** + `DataSource` 实现虚拟列表
- 复杂卡片用 `@Reusable` 池化
- 避免在 `build()` 中创建对象：把表达式提到 `@State`
- 用 `@Track` 标记类字段，让 V1 也能精确订阅
- 60fps 的预算：单帧 ≤ 16.6ms，UI 线程不能阻塞

### 1.3 包大小

- 启用 `obfuscation-rules.txt` 打开混淆与压缩
- `build-profile.json5` 中 `obfuscation.options.enable: true`
- 拆模块：把不常用功能移到 HSP 动态加载
- 用 WebP 代替 PNG，向量优先
- 删除未使用的资源：`hvigorw cleanResources`

### 1.4 内存

- 大对象解除引用后调用 `taskpool.terminate()`
- ArrayBuffer 用 `transferable` 跨线程零拷贝
- 用 Profiler Memory 看堆增长趋势

### 1.5 帧率

- 关注 `view.OnFrame` 与 `RenderService` 的耗时
- 动画用 `animation()` 或 `animateTo()` 而非定时器手动更新

权威路径：`upstream-docs/openharmony-docs/zh-cn/application-dev/performance/`

## 2. 多设备适配

HarmonyOS 一次开发多端部署：手机、平板、折叠屏、PC、车机、智能屏。

### 2.1 响应式断点

```typescript
import { mediaquery } from '@kit.ArkUI';

const listener = mediaquery.matchMediaSync('(width>=600vp)');
listener.on('change', (mq: mediaquery.MediaQueryResult) => {
  this.isTablet = mq.matches;
});
```

或用栅格 `GridRow` / `GridCol`：

```typescript
GridRow({
  columns: { sm: 4, md: 8, lg: 12 },
  gutter: { x: 12, y: 12 }
}) {
  GridCol({ span: { sm: 4, md: 4, lg: 6 } }) { /* card */ }
  GridCol({ span: { sm: 4, md: 4, lg: 6 } }) { /* card */ }
}
```

### 2.2 资源限定

```
resources/
├── base/                ← 缺省
├── zh_CN/
├── en_US/
├── dark/                ← 暗色
├── phone/sw320dp/
└── tablet/sw720dp/
```

文件同名时按设备形态自动选择。

### 2.3 自适应布局

- **Flex** + 百分比尺寸优先
- 使用 vp（virtual pixel）单位
- 字号用 fp，自动响应字号无障碍设置

### 2.4 跨设备协同

- **流转**（Distributed Ability）：从手机把当前 UIAbility 流转到平板继续操作
- **多端协同**：调起远端 ability 完成任务（投屏、打印、扫码）
- API：`@kit.AbilityKit` 的 `wantConstant.Action.ACTION_CONTINUE`

权威路径：
- `upstream-docs/.../ui/responsive-layout.md`
- `upstream-docs/.../application-models/cross-device-migration.md`
- `upstream-docs/.../application-models/multi-device-collaboration.md`

## 3. 安全

### 3.1 数据存储

- 数据库 / Preferences 默认存在 `el2`（用户解锁后可用）；敏感数据用 `el5`（加密 + 用户活跃时可用）
- 用 `@kit.SecurityKit` 的 `cryptoFramework` 做对称 / 非对称加密
- HUKS（Universal Keystore Service）保管密钥，不要硬编码

### 3.2 网络

- HTTPS 必须 + 公钥固定：在 `network_security_config.json` 中配 `pin-set`
- 拒绝明文：`cleartextTraffic: false`
- 证书校验失败不要忽略

### 3.3 权限最小化

- 只声明真正使用的权限
- 敏感权限按需申请，不要一次性弹窗轰炸
- 后台位置 / 后台运行需要单独审核理由

### 3.4 代码安全

- 启用 obfuscation
- 不要把 API Key / 签名密码写进源码（用 `BuildProfile.ets` 的环境变量）
- 用 `cryptoFramework` 校验关键资源完整性

权威路径：`upstream-docs/.../security/`

## 4. 国际化

- 字符串放 `resources/<locale>/element/string.json`
- 通过 `$r('app.string.foo')` 引用，会自动按当前 locale 选择
- 数字 / 日期 / 货币用 `Intl` API
- RTL：在根组件加 `.direction(Direction.Auto)` 自动镜像
- 翻译流程：用 `i18n` Kit 的 `i18n.getSystemLocale()` 检测；上线前导出待翻译表

权威路径：`upstream-docs/.../internationalization/`

## 5. 无障碍

- 给可交互组件设置 `.accessibilityText('描述')`
- 控件分组：用 `Stack` 或 `Container` 配 `accessibilityGroup(true)`
- 自动测试：DevEco 内的 Accessibility Inspector

权威路径：`upstream-docs/.../reference/apis-accessibility-kit/`

## 6. 测试与质量评估

> 展开版见 [`testing-quality` skill](../.claude/skills/testing-quality/SKILL.md)（Local vs ohosTest 铁律、hypium/UiTest 速查、`aa test` CLI、AI 协作范式）+ 可跑模板 [`samples/templates/hypium-uitest/`](../samples/templates/hypium-uitest/)。

### 6.1 单元测试（Local Test）

- 文件位置：`entry/src/test/ets/test/*.test.ets`——**纯逻辑专用**（宿主机跑，不能 import `@kit.*`）
- 框架：`@ohos/hypium`（devDependencies，DevEco 模板自带）；断言是 `expect(x).assertEqual(y)` 族，不是 jest 的 `toBe`
- 跑法：DevEco 右键 Run（带覆盖率）；先把系统 API 调用包成可注入 service，逻辑才可测

### 6.2 设备上测试（Instrument Test / ohosTest）

- 文件位置：`entry/src/ohosTest/ets/test/*.test.ets`——可用全部系统 API + UiTest（`Driver`/`ON`，import 自 `@kit.TestKit`）
- ohosTest 是**独立 HAP，需要签名**；UI 用例只覆盖关键路径，控件定位靠 `.id()` 不靠坐标
- CLI 跑法（CI / AI agent）：`bash tools/harmony-dev-cycle.sh test`（构建两 HAP → 安装 → `hdc shell aa test -s unittest OpenHarmonyTestRunner` → 摘要）

### 6.3 上架前质量评估工位

| 工位 | 用途 |
| --- | --- |
| **AGC 云测（上架自检）** | 提审前必跑：云端真机测兼容性/稳定性/性能/功耗/UX/隐私（AGC → 软件包管理 → 启动自检） |
| DevEco Profiler | 开发期 CPU/内存/帧率/启动耗时 |
| PerfTest（API 20+） | 白盒性能：代码段耗时 + 场景化（启动时延/列表帧率） |
| SmartPerf / wukong | 真机长跑指标采集 / 随机事件稳定性摸底 |

权威路径：`upstream-docs/.../application-test/`（unittest / uitest / perftest / smartperf / wukong 指南齐全）

## 7. CI / 自动化

- GitHub Actions：用 `macos-14`（arm64）runner，下载 SDK 并设置环境
- GitLab CI / Jenkins：参考 `tools/ci-template.yml`（待补）
- 自动化签名见 `00-getting-started/04-signing-and-publishing.md` §5

## 8. 故障观察

- **HiAppEvent**：上报应用自定义事件
- **HiSysEvent**：上报系统事件（崩溃、卡顿、ANR）
- **HiTraceMeter**：trace 性能埋点
- **HiLog**：分级日志，Domain + Tag

权威路径：`upstream-docs/.../dfx/`

## 9. 推荐读物

- `upstream-docs/zh-cn/application-dev/performance/Readme-CN.md`（性能合集）
- `upstream-docs/zh-cn/application-dev/security/Readme-CN.md`（安全合集）
- `upstream-docs/zh-cn/application-dev/dfx/Readme-CN.md`（DFx 合集）
