---
name: harmonyos-signing-publish
description: |
  HarmonyOS 应用签名 + AppGallery Connect 上架流程。
  **激活条件**（满足任一即激活）：
    - 用户提到 .p12 / .cer / .csr / .p7b（签名三件套）
    - 用户问"自动签名失败" / "签名校验失败 9568322" / "调试证书"
    - 用户问 AGC / AppGallery Connect / 实名认证 / ICP 备案
    - 用户准备提审 / 上架被拒（AGC-RJ-* 编号）
    - hvigorw assembleApp -p buildMode=release 相关
  **不激活**：Android 签名（keytool / jarsigner）；iOS 证书；普通 Web 部署。
---

# HarmonyOS 签名与上架

> 触发场景：配签名、生成证书、提交 AGC、审核被拒、灰度发布。

## 签名三件套（与 Android 完全不同）

| 后缀 | 用途 | 来源 |
| --- | --- | --- |
| `.p12` | 私钥 | DevEco 生成 / openssl |
| `.cer` | 证书 | 私钥的 CSR 提交 AGC 申请后获得 |
| `.p7b` | Provision Profile | AGC 中"添加 Profile"后下载 |

**调试 vs 发布是两套独立证书 + Profile，绝不能混用。**

## 调试签名（最快）

DevEco Studio 内置「自动签名」：

1. **File → Project Structure → Signing Configs**
2. 勾 "Automatically generate signature"
3. Sign In 华为账号
4. IDE 自动生成调试 `.p12` `.csr` `.cer` `.p7b`，无需手工申请

调试签名只能用于真机调试和模拟器，**不能上架**。

## 发布签名（手工）

完整流程见 `00-getting-started/04-signing-and-publishing.md`。摘要：

```
1. DevEco 中生成发布 .p12（File → Project Structure → Signing Configs → Generate）
2. 用 .p12 生成 .csr（命令行或 DevEco UI）
3. 登录 AGC https://developer.huawei.com/consumer/cn/service/josp/agc/index.html
4. AGC 中：用户与访问 → API 密钥管理 → 应用调测 / 发布证书 → 上传 .csr → 下载 .cer
5. AGC 中：我的项目 → 我的应用 → 应用信息 → 添加 Profile → 关联 .cer → 下载 .p7b
6. 在 build-profile.json5 / DevEco 中配置签名参数
```

## release 构建命令

```bash
hvigorw clean && ohpm install
hvigorw assembleApp -p buildMode=release \
  -p storeFile=$KEYSTORE_FILE \
  -p storePassword=$KEYSTORE_PWD \
  -p keyAlias=$KEY_ALIAS \
  -p keyPassword=$KEY_PWD \
  -p signAlg=SHA256withECDSA \
  -p profile=$PROFILE_FILE \
  -p certpath=$CERT_FILE
```

**密码绝不硬编码**：用 `${env.HOS_KEYSTORE_PWD}` 或 CI Secret。

## 上架 AGC

| 步骤 | 备注 |
| --- | --- |
| 1. 实名认证华为账号 | 个人 99¥/年 / 企业 600¥/年 |
| 2. AGC 创建应用 | bundleName 必须与 `app.json5` 一致 |
| 3. 编译 release `.app` | 用上面命令 |
| 4. 上传 `.app` | AGC → 我的应用 → 版本管理 |
| 5. 填基础信息 | 应用名、图标、截图、隐私政策 URL、权限说明 |
| 6. 提交审核 | 一般 1–3 工作日 |
| 7. 灰度发布 | 可选，先放量 1%–10% 观测 |
| 8. 全量发布 | 通过审核后手动点上架 |

## 常见审核拒因

- 缺隐私政策 URL（必须 HTTPS）
- 权限申请未在 UI 中说明用途
- 应用名/图标违反规范
- 闪退率高（提交前要在多机型测）
- 用了未声明的 SystemCapability
- 调试日志泄漏（hilog 未脱敏字段）

## 多模块（多 hap）打包

```
.app
├── entry.hap     ← 默认入口
├── feature1.hap  ← 动态特性
└── feature2.hap
```

`build-profile.json5` 中配 `products[].entryModule = 'entry'`，`featureModules` 列其他。

## 进一步参考

- 完整流程：`00-getting-started/04-signing-and-publishing.md`
- 上架细则：`07-publishing/README.md`
- AGC 文档：https://developer.huawei.com/consumer/cn/service/josp/agc/index.html
