# hypium 单元测试 + UiTest 最小模板

> verified_against: harmonyos-6.1.1-api24 · docs-checked 2026-07-09
> 对应 skill：[`testing-quality`](../../../.claude/skills/testing-quality/SKILL.md)

两个可粘贴文件，覆盖鸿蒙测试的两种形态：

| 文件 | 放到你工程的哪里 | 跑在哪 |
| --- | --- | --- |
| `CalcLogic.test.ets` | `entry/src/test/ets/test/`（Local Test，纯逻辑） | 宿主机，秒级反馈 |
| `LoginPage.uitest.test.ets` | `entry/src/ohosTest/ets/test/`（Instrument Test） | 设备/模拟器 |

## 使用步骤

1. 确认 `entry/oh-package.json5` devDependencies 里有（DevEco 模板默认自带）：

```json
"devDependencies": {
  "@ohos/hypium": "1.0.25",
  "@ohos/hamock": "1.0.0"
}
```

2. 把文件拷到对应目录，并在同目录的 `List.test.ets` 注册（DevEco 模板自带该汇总文件）：

```typescript
import calcLogicTest from './CalcLogic.test';

export default function testsuite() {
  calcLogicTest();
}
```

3. 跑法三选一：
   - **DevEco GUI**：右键测试文件 → Run（Local 与 Instrument 都支持，带覆盖率视图）
   - **CLI（设备路线，ohosTest）**：`bash tools/harmony-dev-cycle.sh test`（本仓封装：构建两个 HAP → 安装 → `aa test` → 抓结果）
   - **裸命令**：见 [`testing-quality` skill §四](../../../.claude/skills/testing-quality/SKILL.md)

## 注意事项（跑不通先看这里）

- **ohosTest HAP 需要签名**：DevEco 勾了自动签名会一起签；CLI 构建报 9568322 先查 signingConfigs
- **Local Test 不能 import `@kit.*`**：带系统 API 的用例只能放 `ohosTest/`
- **异步用例必须调 `done()`**，否则按超时失败
- **UiTest 定位靠 `.id()`**：先给页面关键控件加 `.id('loginBtn')` 再写用例，不要用坐标
- 断言是 `expect(x).assertEqual(y)` 族——**不是** jest 的 `toBe`（AI 惯性错误，编译不过）
- 测试环境与生产隔离：endpoint / 账号不要硬编码生产值（review 规则 `TEST-002`）

## 上 PR 前 checklist

- [ ] `bash tools/hooks/lib/scan-arkts.sh <文件>` exit 0
- [ ] Local 单测在 DevEco 里绿
- [ ] UiTest 在模拟器/真机跑通一次（`harmony-dev-cycle.sh test`）
- [ ] 提审前跑 AGC 云测上架自检（兼容性/稳定性/隐私）
