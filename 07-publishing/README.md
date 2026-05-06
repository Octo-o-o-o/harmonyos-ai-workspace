# 发布与上架

详细签名步骤见 [`../00-getting-started/04-signing-and-publishing.md`](../00-getting-started/04-signing-and-publishing.md)。本文档覆盖发布全流程的其他环节。

> **提审前必看**：[`checklist-2026-rejection-top20.md`](checklist-2026-rejection-top20.md) —— Top 20 拒因 + 修复 + 自查命令，能避开 80% 的"上传后被拒"。

## 1. 注册开发者账号

- 个人：<https://developer.huawei.com/consumer/cn/console>
- 企业：同上，需要营业执照
- 实名认证：身份证 / 公司证件 + 银行卡 4 元小额验证（个人）

> 没有华为开发者账号无法发布、无法做真机调试签名、无法接入推送 / 地图等付费服务。

## 2. AppGallery Connect (AGC)

AGC 是华为应用云服务统一控制台，相当于 Apple App Store Connect。

入口：<https://developer.huawei.com/consumer/cn/service/josp/agc/index.html>

主要功能：

- 应用注册（生成 bundleName 与 App ID）
- 证书与 Profile 管理
- HAP / App 包上传与版本管理
- 推送服务、AppLinking、A/B 测试
- 闪屏分析、崩溃分析、性能监控
- 国际版（中外双站点）

## 3. 完整流程

```
[1] 注册 + 实名
       ↓
[2] AGC 创建项目和应用 → 拿到 bundleName 与 App ID
       ↓
[3] 本地生成 .p12 + .csr     （keytool 或 IDE）
       ↓
[4] AGC 申请发布证书 (.cer) 和发布 Profile (.p7b)
       ↓
[5] DevEco 配置 Signing Configs（项目级）
       ↓
[6] hvigorw assembleApp -p buildMode=release  ← 出 .app
       ↓
[7] AGC 上传 .app + 应用资料 + 隐私政策
       ↓
[8] 提交审核（1-3 天）
       ↓
[9] 发布上架
```

## 4. 上架材料清单

- 应用名称（≤ 28 字符）
- 应用图标 1024×1024 PNG
- 应用一句话简介（≤ 80 字符）
- 应用详细描述
- 截图 5-10 张（按设备类型分别上传）
- 视频（可选，长度 ≤ 60s）
- 隐私政策 URL（可公网访问）
- 用户协议 URL
- 应用分类
- 联系邮箱
- 开发者网站
- 测试账号（如果有登录功能）

## 5. 版本管理

```
versionCode: 整数，每次提审递增（1000000 → 1000001）
versionName: 用户可见的字符串 "1.0.0" "1.0.1"
```

`AppScope/app.json5`：

```json5
{
  "app": {
    "bundleName": "com.example.demo",
    "vendor": "example",
    "versionCode": 1000001,
    "versionName": "1.0.1",
    "icon": "$media:app_icon",
    "label": "$string:app_name",
    "minAPIVersion": 12,
    "targetAPIVersion": 20
  }
}
```

## 6. 内测与灰度

AGC 支持：

- **内部测试**：直接发给指定 UDID 设备
- **公开测试**：开放下载链接，给一组用户
- **生产灰度**：按比例分发新版本，监控指标后再全量

## 7. 推送 / 云函数 / 数据库等增值服务

需要在 AGC 中开通：

- **Push Kit**：推送（免费）
- **AppLinking**：深链
- **AGC Cloud DB**：云数据库
- **Cloud Function**：FaaS
- **Authentication**：账号体系
- **Analytics**：用户行为分析

接入文档统一在 <https://developer.huawei.com/consumer/cn/agc/>。

## 8. 全球化发布

- 中国大陆：通过中国 AGC 上架华为应用市场（应用市场 / Petal）
- 海外：通过 AGC 国际版上架 AppGallery（一些海外用户用 GMS 替代品）
- 上架审核可同时进行

## 9. 常见拒审原因

| 原因 | 解决 |
| --- | --- |
| 隐私政策缺失或链接 404 | 提供可公网访问的隐私政策 |
| 截图不真实 / 模糊 / 含浮水印 | 用模拟器截真实运行画面 |
| 申请权限与功能不匹配 | 删除不必要权限，或在隐私政策中说明 |
| 应用闪退 | 用 Profiler 复现并修复 |
| 抄袭 / 商标侵权 | 修改 UI / 名称，提供商标证明 |
| 内购未走华为 IAP | 接入华为内购 SDK |
| 第三方账号登录但未提供注销 | 增加注销功能 |

## 10. 参考

- AGC 官方文档：<https://developer.huawei.com/consumer/cn/doc/distribution/app/agc-help-releaseapp-0000001146642648>
- 应用上架自检清单：<https://developer.huawei.com/consumer/cn/doc/distribution/app/agc-help-newapp-rules-0000001146641714>
- HarmonyOS 应用商业化政策：<https://developer.huawei.com/consumer/cn/agreement/>
