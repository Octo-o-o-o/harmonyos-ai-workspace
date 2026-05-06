# Recipe 模板

> 把"hello world 之后的第一个真功能"拆成 4 个高频小场景。每个 recipe 是**完整可运行**的最小代码 + 关键约束 + 反模式提醒，AI 写新功能时可参考。
>
> **不是脚手架**——这些是片段，用来粘到你已有的 DevEco 工程里。完整工程见 [`docs/SETUP-FROM-SCRATCH.md`](../../docs/SETUP-FROM-SCRATCH.md)。

## 目录

| Recipe | 内容 | 验证状态 |
| --- | --- | --- |
| [`permission/`](permission/) | 4 类常见权限（位置 / 相机 / 通知 / 麦克风）的运行时申请 + 拒绝兜底 + UI 解释 | 完整代码（`AGC-RJ-002` 合规） |
| [`list/`](list/) | LazyForEach + IDataSource 长列表 + 下拉刷新 + 上拉加载更多 | 完整代码（`PERF-002` 合规） |
| [`dark-mode/`](dark-mode/) | 系统主题跟随 + 深色资源文件 + `$r('sys.color.ohos_id_color_*')` | 完整代码（`AGC-RJ-016` 合规） |
| [`login/`](login/) | 华为账号 SSO 登录（`@kit.AccountKit` 的 AuthAccount） | **指引型**——含官方文档链接 + 关键约束；不写完整代码以避免 AI 训练数据误导 |

## 用法

1. 找到对应场景的目录
2. 看 README 里的"约束"段（必须满足的鸿蒙规则）
3. 复制 `*.ets` 文件到你的 `entry/src/main/ets/pages/` 或 `components/`
4. 按 README 末尾的"集成步骤"在 `module.json5` / `oh-package.json5` 加配置

## 维护

- 鸿蒙 API 6.x → 7.x 大版本迭代时审视一遍（约 12 月）
- 每个 recipe 都引用了对应的 `XXX-NNN` 规则 ID。规则更新时同步 recipe 注释
- 真实跑通过的 SDK 版本在每个 README 顶部标注（`verified_against: harmonyos-6.0.2-api22`）

## 不在这里的内容

- **业务模块完整脚手架**（如完整购物车、聊天）—— PLAN.md 明确不做（半衰期短）
- **第三方 SDK recipe**（百度地图 / 微信支付 / 极光推送等）—— v0.3 候选，需要 SDK 提供方愿意贡献

如果你写了一个 recipe 想进来，看 [`CONTRIBUTING.md`](../../CONTRIBUTING.md)。
