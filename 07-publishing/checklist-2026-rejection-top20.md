# AppGallery 提审 · Top 20 拒因清单（2026 版）

> 综合 AGC 官方审核标准、华为开发者论坛真实拒因案例、CSDN / 掘金多个开发者复盘，**按出现频率排序**。
>
> 提审前对照本清单走一遍，能避开 80% 以上的"上传后被拒"。
>
> 每条带稳定 ID（`AGC-RJ-001` ...），review skill 与 `harmonyos-review` 报告中可引用。

## 高频拒因（前 10）

### `AGC-RJ-001` 隐私政策缺失或不可访问

- 必须有**独立 HTTPS URL**（不能放在 app 内）
- 首次启动**必须弹窗**展示，用户明确同意才能继续
- 政策中必须列出：收集哪些个人信息、第三方 SDK 列表、是否跨境、保存周期
- 修复：用 [华为开发者隐私模板](https://developer.huawei.com/consumer/cn/agconnect/help/privacy-policy/) 起草，部署到自有域名

### `AGC-RJ-002` 权限申请缺合理性

- 申请的每个 `ohos.permission.*` 都要在 UI 中**说明用途**
- 用户拒绝后必须有**可继续使用的退路**
- 禁止"一次申请所有权限"
- 修复：在 `aboutToAppear` 后用 `requestPermissionsFromUser` 单独申请，每次申请前给 1-2 句解释

### `AGC-RJ-003` 实名认证 / 资质缺失

- 涉及金融、游戏、医疗、新闻、社交、电商的 app 需要对应资质
- 个人开发者**不能**上架金融、医疗类
- 修复：在 AGC 应用信息页上传资质扫描件；类目选错的需要重新提交

### `AGC-RJ-004` 应用图标 / 启动图违规

- 图标不能用华为系统图标 / 商标
- 启动图不能含**广告内容、第三方 logo**
- 图标必须**最大 1024×1024 PNG**，圆角自动处理
- 修复：用 DevEco "图标制作" 工具或 AGC 在线工具

### `AGC-RJ-005` 闪退 / ANR 高发

- AGC 自动跑稳定性测试，crash 率 > 0.5% 拒
- ANR > 0.3% 拒
- 修复：提交前在多机型（Mate / Pura / Nova）跑 30 分钟以上压测；用 `hilog` 看 crash 日志

### `AGC-RJ-006` API Level 与 minSdk 不匹配

- `compileSdkVersion ≥ targetSdkVersion ≥ minSdkVersion`
- 用了 API 21+ 新特性但 minSdk 是 12，没有 `canIUse('SystemCapability.X')` 守护 → 拒
- 修复：要么提高 minSdk；要么加守护

### `AGC-RJ-007` 调试日志泄漏

- release 包不能含 `console.log`
- `hilog` 不能用 `%{public}` 输出敏感字段（口令 / token / 身份证）
- 修复：跑 `hvigorw assembleApp -p buildMode=release` 时启用混淆 + log 剥离

### `AGC-RJ-008` 误导性广告 / 暗黑模式

- 广告位不能伪装成 UI 控件
- 不能"必须看广告才能用"（除非声明为广告应用）
- 弹窗关闭按钮必须 ≥ 24×24 dp，且与广告内容颜色对比清晰
- 修复：广告位需明确标"广告"二字；关闭键合规化

### `AGC-RJ-009` 后台执行权限滥用

- 后台定位、后台播放、后台运行任务必须有**用户可见的前台通知**
- 不能"sleep 后还在抓数据"
- 修复：用 `@kit.BackgroundTasksKit` 的 `continuousTask` 注册前台服务

### `AGC-RJ-010` 跨境数据 / 第三方 SDK 未声明

- 接入百度地图、友盟、Bugly 等都要在隐私政策中声明
- 数据流向境外服务器需要明确告知用户
- 修复：列清楚每个第三方 SDK 收集什么数据、传到哪里

## 中频拒因（11-20）

### `AGC-RJ-011` 应用名 / 描述违规

- 不能含 "鸿蒙官方"、"华为官方"
- 描述不能与实际功能不符
- 修复：用准确、克制的描述

### `AGC-RJ-012` 内购 / 支付未走 IAP

- 数字商品销售必须用华为 IAP（@kit.IAPKit），抽成 30%（小额 15%）
- 实物销售可以用第三方支付
- 修复：数字商品改 IAP

### `AGC-RJ-013` UI 布局适配错乱

- 折叠屏未适配横竖屏切换
- 平板布局未做断点适配
- 修复：用 `@ohos.mediaquery` + `BreakpointSystem` 做响应式

### `AGC-RJ-014` 国际化字符串硬编码

- 中文写死在 `.ets` 里，未走 `resources/base/element/string.json` + `$r('app.string.xxx')`
- 修复：迁移所有 UI 文案到 string.json

### `AGC-RJ-015` 包大小过大

- 单 HAP 推荐 < 200 MB；超过 1 GB 严重影响审核通过率
- 修复：大资源走 HSP 动态加载或后端下载；图片用 WebP / 矢量图

### `AGC-RJ-016` 未适配深色模式

- 强制用户跟随系统主题
- 没有深色模式视为体验问题（不一定拒，但影响评分）
- 修复：用 `$r('sys.color.ohos_id_color_*')` 系统色

### `AGC-RJ-017` 启动速度慢

- 冷启动 > 2 秒拒
- 修复：用 Profiler 分析；首屏数据用占位 + 异步填充；非必要逻辑放 `aboutToAppear` 之后

### `AGC-RJ-018` 网络异常处理缺失

- 网络断开时没有 UI 提示
- API 失败后无重试 / 兜底
- 修复：所有 `http.request` 都要有 catch + UI 反馈

### `AGC-RJ-019` 卸载残留

- 卸载后还有数据残留（Preferences / RDB / 文件）
- 修复：默认数据走 sandbox（`getContext().filesDir`），系统会随卸载清理；不要硬写绝对路径

### `AGC-RJ-020` 版本号管理混乱

- `versionCode` 必须严格递增
- `versionName` 不能含中文 / 特殊字符
- 同一 versionCode 不能重复提交
- 修复：用 `versionCode = major * 10000 + minor * 100 + patch` 自动生成

---

## 提审前自查命令

```bash
# 1. 包大小
ls -lh entry/build/default/outputs/default/*.hap

# 2. 权限清单
grep -A 20 '"requestPermissions"' entry/src/main/module.json5

# 3. 硬编码中文（应该几乎没有）
grep -rn "'[一-鿿]" entry/src/main/ets/ | head -20

# 4. console 日志（release 必须 0）
grep -rn 'console\.' entry/src/main/ets/

# 5. 三方 SDK 清单
grep -A 50 '"dependencies"' oh-package.json5 entry/oh-package.json5

# 6. 跑钩子全扫
find entry/src/main/ets -name '*.ets' -exec bash tools/hooks/lib/scan-arkts.sh {} \;

# 7. 包名校验
bash tools/check-ohpm-deps.sh

# 8. 真编译期 lint
bash tools/run-linter.sh --strict
```

---

## 拒因申诉

被拒后：

1. AGC 后台 → 我的应用 → 审核记录 → 拒绝详情
2. 如果是误判：附上具体证据（截图 / 视频 / 日志），点"申诉"
3. 一般 1-2 工作日有人工复审
4. 重复被拒 3 次：建议联系 [开发者支持](https://developer.huawei.com/consumer/cn/support/)

---

## 维护说明

本清单基于 2026-05 阶段调研，AGC 审核标准每季度可能微调。建议：

- 每次有应用被拒，把拒因摘录补到本清单
- 每季度从 [AGC 官方审核标准](https://developer.huawei.com/consumer/cn/doc/distribution/app/agc-help-checkdevelop-0000001146642468) 同步一遍
- 重大版本（如 HarmonyOS 7）发布后 1 个月内重审本清单
