---
name: testing-quality
verified_against: harmonyos-6.1.1-api24  # docs-checked 2026-07-09（对照官方 Test Kit 指南核验，未逐条真机重跑）
description: |
  鸿蒙应用测试 + 质量评估：hypium 单元测试 / UiTest UI 自动化 / `aa test` 命令行 / 上架前质量工位（AGC 云测·SmartPerf·wukong·Profiler）。
  **激活条件**（满足任一即激活）：
    - 用户说"写测试 / 单元测试 / UI 测试 / 自动化测试 / 测试覆盖率"
    - 代码或依赖出现 `@ohos/hypium`、`@ohos/hamock`、`@kit.TestKit`、`Driver`、`ON.`、`ohosTest`
    - 用户跑 `hdc shell aa test` / DevEco "Run Tests" 出错
    - 用户问"上架前怎么自测 / 怎么评估 app 质量 / 性能摸底 / 稳定性测试 / 云测"
  **不激活**：本仓库自身的 tools/test-suite.sh（那是工具包回归，不是鸿蒙 app 测试）；Web/Node 项目的 jest/vitest。
---

# 鸿蒙测试与质量评估专项

> 官方测试底座 = **Test Kit**（`@kit.TestKit`）三件套：**JsUnit 单元测试**（`@ohos/hypium`）+ **UiTest UI 测试**（`Driver`/`ON`）+ **PerfTest 白盒性能**（API 20+）。
> 权威文档在本地镜像：`upstream-docs/openharmony-docs/zh-cn/application-dev/application-test/`（unittest / uitest / perftest / smartperf / wukong 各有指南）。
> 可跑模板：[`samples/templates/hypium-uitest/`](../../../samples/templates/hypium-uitest/)。

## 一、两个测试目录的铁律（最高频混淆）

| 目录 | 名称 | 跑在哪 | 能用什么 | 适合 |
| --- | --- | --- | --- | --- |
| `entry/src/test/` | Local Test | 宿主机 Node 环境 | **纯逻辑**（不含 @kit.* 系统 API、不含 UI） | 工具函数、数据转换、协议编解码 |
| `entry/src/ohosTest/` | Instrument Test | **设备/模拟器上**（打成独立 ohosTest HAP） | 全部系统 API + UiTest + AbilityDelegator | UI 流程、Ability 生命周期、系统能力集成 |

- 铁律 1：**测试文件命名 `*.test.ets`**，放 `src/{test,ohosTest}/ets/test/` 下，并在同目录 `List.test.ets` 汇总注册（DevEco 模板自带）。
- 铁律 2：**涉及任何 `@kit.*` 系统 API 的用例只能放 ohosTest**——Local Test 环境没有系统 API 实现，AI 最常犯的错是把带 `@kit.AbilityKit` import 的用例塞进 `src/test/`。
- 铁律 3：ohosTest HAP 是**独立 HAP，需要签名**——自动签名勾选时 DevEco 会一起签；CLI 构建报签名错先查 `build-profile.json5` 的 signingConfigs 是否覆盖 ohosTest target。

## 二、hypium 单元测试速查

依赖（DevEco 模板 devDependencies 自带，不要挪进 dependencies）：

```json
"devDependencies": { "@ohos/hypium": "1.0.25", "@ohos/hamock": "1.0.0" }
```

官方骨架（ohosTest 形态，来自 unittest-guidelines）：

```typescript
import { describe, expect, it, Level, Size, TestType } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { UIAbility, Want } from '@kit.AbilityKit';

const delegator = abilityDelegatorRegistry.getAbilityDelegator();

export default function abilityTest() {
  describe('ActsAbilityTest', () => {
    it('testExample', TestType.FUNCTION | Size.MEDIUMTEST | Level.LEVEL1, async (done: Function) => {
      const bundleName = abilityDelegatorRegistry.getArguments().bundleName;
      const want: Want = { bundleName: bundleName, abilityName: 'EntryAbility' };
      await delegator.startAbility(want);
      const ability: UIAbility = await delegator.getCurrentTopAbility();
      expect(ability.context.abilityInfo.name).assertEqual('EntryAbility');
      done();   // ⚠️ 异步用例必须调 done()，否则按超时失败
    })
  })
}
```

高频断言族：`assertEqual` / `assertTrue` / `assertContain` / `assertNull` / `assertUndefined` / `assertThrowError` / `assertDeepEquals`（对象深比较）/ `assertNaN` / `assertLarger` / `assertLess`。

其他能力一句话：

- **Mock**：`@ohos/hamock` 提供函数级 mock（`MockKit` + `when(...).afterReturn(...)`）——只 mock 自己的类方法，不要试图 mock `@kit.*` 系统模块（不支持，改用依赖注入把系统调用包一层）。
- **数据驱动**：`Hypium.setData()` + it 内取参，复用同一脚本跑多组输入。
- **生命周期钩子**：`beforeAll / beforeEach / afterEach / afterAll`（describe 内注册）。
- **筛选**：it 第二参的 `TestType | Size | Level` 位或组合，配合 `aa test -s testType/-s level` 过滤。

## 三、UiTest UI 自动化速查

```typescript
import { describe, it, expect } from '@ohos/hypium';
import { Driver, ON } from '@kit.TestKit';   // API 9+ 老代码是 @ohos.UiTest，新代码统一 @kit.TestKit

export default function loginUiTest() {
  describe('LoginUiTest', () => {
    it('tap_login_and_expect_home', 0, async (done: Function) => {
      const driver = Driver.create();
      await driver.delayMs(1000);                                   // 等首页渲染
      const btn = await driver.findComponent(ON.id('loginBtn'));    // 优先 ON.id，其次 ON.text
      expect(btn !== null).assertTrue();
      await btn.click();
      // ✅ 等待新页面：用 waitForComponent（带超时轮询），不要堆 delayMs 猜时间
      const home = await driver.waitForComponent(ON.text('首页'), 3000);
      expect(home !== null).assertTrue();
      done();
    })
  })
}
```

常用 API 工位：

| 要做什么 | API |
| --- | --- |
| 找控件 | `driver.findComponent(ON.id('x') / ON.text('登录') / ON.type('Button'))` |
| 等控件出现 | `driver.waitForComponent(on, timeoutMs)` ← 优先于 `delayMs` |
| 等界面空闲 | `driver.waitForIdle(idleMs, timeoutMs)` |
| 点击/长按/双击 | `component.click()` / `longClick()` / `doubleClick()` |
| 输入文本 | `component.inputText('abc')`（先 `clearText()`） |
| 滑动/fling | `driver.swipe(x1,y1,x2,y2)` / `driver.fling(...)` |
| 截图 | `driver.screenCap('/data/local/tmp/1.png')` |
| 系统弹窗/toast | `driver.createUIEventObserver()` 监听（拿提示文本断言） |

反模式（AI 高频）：

- ❌ 用绝对坐标 `driver.click(540, 1200)` ——换设备/分辨率必挂；用 `ON.id`/`ON.text` 定位。
- ❌ 给可测控件不加 `.id('xxx')` ——写页面时就给关键交互控件加 id，UiTest 才有稳定锚点。
- ❌ `delayMs(5000)` 连环堆 ——用 `waitForComponent` / `waitForIdle`，快且稳。
- ❌ UI 用例覆盖一切 ——UI 测试只保关键路径（登录、下单、核心跳转）；逻辑覆盖交给 Local 单测。

## 四、命令行执行（CI / AI agent 路线）

官方路径 = 把 ohosTest HAP 装上设备后用 `aa test` 触发（`OpenHarmonyTestRunner` 是模板自带 runner）。`test` 是 hvigor 内置第三种 buildMode（"运行 ohosTest 测试套件推荐选项"，不出现在 build-profile 里但真实存在）：

```bash
# 1) 构建（主 HAP + ohosTest HAP，均用 buildMode=test）
hvigorw --mode module -p module=entry@default  -p product=default -p buildMode=test assembleHap
hvigorw --mode module -p module=entry@ohosTest -p buildMode=test assembleHap

# 2) 安装两个 HAP（产物在 default/ 与 ohosTest/ 两个 outputs 子目录）
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc install -r entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap

# 3) 触发测试（-m 是测试 module 名，DevEco 模板默认 entry_test）
hdc shell aa test -b com.example.app -m entry_test -s unittest OpenHarmonyTestRunner -s timeout 15000
# DevEco 实际调用的 runner 全路径变体（个别工程需要）：
#   -s unittest /ets/testrunner/OpenHarmonyTestRunner

# 常用过滤参数（-s 键 值）
#   -s class s1,s2          只跑指定测试套 / -s class suite#case 单条
#   -s itName xxx           按用例名
#   -s breakOnError true    遇错即停
#   -s level 0 / -s size small / -s testType function   按 it 第二参筛选
#   -s coverage true        覆盖率采集
```

结果在 shell 输出（`OHOS_REPORT_*` 行）+ hilog。**本仓封装**：`bash tools/harmony-dev-cycle.sh test` 一键跑完上面 1→3 并抓结果摘要。

## 五、上架前质量评估工位（什么时候用哪个）

| 工位 | 干什么 | 什么时候用 |
| --- | --- | --- |
| **AGC 云测（上架自检）** | 云端真机农场自动测兼容性/稳定性/性能/功耗/UX/**隐私** | **每次提审前必跑**：AGC → 软件包管理 → "启动自检"（或邀请测试→启动自检）。拒审 Top 因子（隐私合规）能提前暴露 |
| **DevEco Profiler** | CPU/内存/帧率/启动耗时火焰图 | 开发期性能摸底；结合 `build-debug` skill 的调试闭环 |
| **PerfTest**（API 20+） | 白盒：代码段耗时/CPU/内存 + 场景化（启动时延/页面切换/列表帧率） | 有明确性能预算的关键路径回归 |
| **SmartPerf** | CLI 采集 FPS/CPU/GPU/RAM/功耗/温度 | 真机长跑观测、竞品对比 |
| **wukong** | 随机事件注入（monkey 等价物）+ 异常捕获 | 稳定性摸底：`hdc shell wukong exec -s 10 -i 1000 -a 0.28 -t 0.72 -c 100`（官方示例参数：种子/间隔ms/点击比/触摸比/次数） |
| **DevEco Code verify_ui**（官方 AI agent，可选） | 多模态模型驱动的 UI 意图验证 | 已用 DevEco Code 的团队可作为 UI 走查补充；本仓不依赖 |

## 六、AI 写测试的协作范式

1. **先写 Local 纯逻辑单测**（`src/test/`）：不依赖设备、秒级反馈、AI 产出可信度最高。让被测逻辑**先解耦**——把系统 API 调用包进可注入的 service 类，纯逻辑才可测。
2. UI 用例只覆盖关键路径，并要求页面控件**先补 `.id()`**。
3. 跑不通先查三板斧：ohosTest HAP 没签名（9568322）/ runner 模块名不对（`-m entry_test`）/ 异步用例没调 `done()`。
4. 测试代码同样受 ArkTS 严格规则约束（`arkts-rules` skill 全部适用）——AI 惯性写 jest 风格 `test()` / `expect(x).toBe(y)` 是编译不过的，鸿蒙断言是 `expect(x).assertEqual(y)`。
5. 测试不要连生产环境：endpoint/账号走 ohosTest 专用配置（review 规则 `TEST-002`）。

## 相关规则 ID

- `TEST-001`（Medium）：核心业务逻辑（service/utils/viewmodel 层）没有任何 hypium 单测——提示补齐，不阻断
- `TEST-002`（High）：ohosTest 用例硬编码生产环境 endpoint / 真实用户凭据
- 完整审查清单：[`harmonyos-review`](../harmonyos-review/SKILL.md)

## 进一步参考

- 本地官方指南：`upstream-docs/.../application-test/{unittest,uitest,perftest,smartperf,wukong}-guidelines.md`
- 可跑模板：[`samples/templates/hypium-uitest/`](../../../samples/templates/hypium-uitest/)
- CLI 闭环：`bash tools/harmony-dev-cycle.sh test`（见 `04-build-debug-tools/README.md`）
- 云测入口：AppGallery Connect → 应用上架 → 软件包管理 → 启动自检
