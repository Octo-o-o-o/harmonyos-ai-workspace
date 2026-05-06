# 签名与发布

HarmonyOS 应用的签名和发布流程比 Android 复杂，有 **调试签名** 与 **发布签名** 两套体系，且都依赖华为开发者账号。

## 1. 概念

| 概念 | 含义 |
| --- | --- |
| **HOS 应用证书** (`.cer`) | 由 AGC 颁发，绑定开发者身份 |
| **私钥** (`.p12`) | 本地生成，与证书配对 |
| **CSR** (`.csr`) | 证书申请请求文件，由 `.p12` 派生 |
| **Profile** (`.p7b`) | 描述文件，绑定证书 + bundleName + 设备列表（调试） |
| **签名后包** | `.hap` (单模块) / `.app` (上架包) |

## 2. 调试签名（最快开始）

最简单：让 DevEco 自动签名。

1. **File → Project Structure → Project → Signing Configs**
2. 勾选 ✅ **Automatically generate signature**
3. 点 **Sign In** 登录华为账号
4. IDE 自动生成 `.p12` `.csr`，并在 AGC 申请调试证书与 profile
5. 完成后会看到：
   ```
   Store file: ~/.signature/<bundle>.p12
   Store password: 自动生成
   Key alias: ...
   Profile file: ~/.signature/<bundle>_profile.p7b
   ```

> **限制**：自动调试签名只能装到登录账号下的真机，且不能上架。

## 3. 发布签名（手动）

### 3.1 生成 `.p12` 私钥

DevEco 内：**Build → Generate Key and CSR**

- Key store file：选个路径保存 `.p12`
- Password / Confirm Password：**记牢，丢了无法找回**
- Alias / Key password：填一个 alias 名
- 有效期：建议 ≥ 25 年
- Country / State / ... 填实
- Click Next，会提示生成 `.csr`

或命令行（OpenSSL）：

```bash
keytool -genkeypair -alias myalias -keyalg EC -groupname secp256r1 \
  -keystore /path/to/my.p12 -storetype pkcs12 -validity 9125 \
  -storepass <password> -dname "CN=Your Name, OU=Dev, O=Org, L=City, ST=State, C=CN"

keytool -certreq -alias myalias -keystore /path/to/my.p12 \
  -storetype pkcs12 -file /path/to/my.csr -storepass <password>
```

### 3.2 在 AGC 申请发布证书

1. 登录 <https://developer.huawei.com/consumer/cn/service/josp/agc/index.html>
2. **用户与访问 → 证书管理 → 新增证书**
3. 类型选 **发布证书**
4. 上传上一步生成的 `.csr`
5. 下载得到 `.cer`

### 3.3 申请发布 Profile

1. AGC：**HarmonyOS → 我的项目 → 选择应用 → HAP Provision Profile**
2. 类型选 **Release**
3. 关联前一步的发布证书
4. （可选）添加白名单设备（仅对内测有意义）
5. 下载得到 `.p7b`

### 3.4 在 DevEco 中配置

```
Project Structure → Signing Configs → 取消 Automatically generate signature
```

然后填入：

| 字段 | 值 |
| --- | --- |
| Store file | `/path/to/my.p12` |
| Store password | 你设置的密码 |
| Key alias | myalias |
| Key password | 同上 |
| Sign alg | SHA256withECDSA |
| Profile file | `/path/to/release.p7b` |
| Certpath file | `/path/to/release.cer` |

## 4. 上架 AppGallery

### 4.1 准备

- **应用图标**：1024×1024 PNG
- **截图**：5-10 张，分辨率匹配设备
- **描述**：中英文（如果上架国际版）
- **隐私政策**：必须有公网链接
- **测试账号**：如果有登录功能，提供测试账号

### 4.2 上传

1. AGC → **我的项目 → 选择应用 → 应用信息**
2. 完善基础信息（名称、分类、应用图标）
3. **版本信息**：上传 `.app` 包（注意是 `.app`，不是 `.hap`）
   - 命令行：`hvigorw assembleApp -p buildMode=release`
   - 产物：`{project}/build/outputs/default/{app-name}-default-signed.app`
4. 填写隐私 / 内容评级 / 商业信息
5. 提交审核（通常 1-3 天）

### 4.3 必要的 metadata

`AppScope/app.json5`:

```json5
{
  "app": {
    "bundleName": "com.example.helloharmony",
    "vendor": "example",
    "versionCode": 1000000,
    "versionName": "1.0.0",
    "icon": "$media:app_icon",
    "label": "$string:app_name"
  }
}
```

`entry/src/main/module.json5` 中声明使用的能力 / 权限：

```json5
{
  "module": {
    "requestPermissions": [
      {
        "name": "ohos.permission.INTERNET",
        "reason": "$string:permission_internet_reason",
        "usedScene": {
          "abilities": ["EntryAbility"],
          "when": "always"
        }
      }
    ]
  }
}
```

## 5. CI / 自动化签名

```bash
# 1) 在 build-profile.json5 引用环境变量保存的密码
# 2) CI 上设 KEYSTORE_PASSWORD 等环境变量
# 3) 用 hvigorw 直接构建 release
hvigorw clean assembleApp -p buildMode=release \
  -p storePassword=$KEYSTORE_PASSWORD \
  -p keyPassword=$KEY_PASSWORD
```

GitHub Actions 模板示例放在 [`../tools/ci-template.yml`](../tools/ci-template.yml)（待补）。

## 6. 常见问题

| 问题 | 解决 |
| --- | --- |
| 上传 `.app` 报 `signature not match` | 确认证书与 profile 是同一份，且 profile 有效期未过 |
| AGC 找不到 `HAP Provision Profile` | 确认应用类型是 HarmonyOS，而不是 Android |
| 调试证书数量受限 | 个人账号每年有限额，到期重生成；公司账号可申请增加 |
| `Permission denied` 安装到真机 | 设备未授权调试，或 profile 中没有该设备 UDID |

## 7. 参考

- AGC 文档：<https://developer.huawei.com/consumer/cn/service/josp/agc/index.html>
- 签名机制官方说明：`upstream-docs/openharmony-docs/zh-cn/application-dev/security/`
- AppGallery 上架指引：<https://developer.huawei.com/consumer/cn/doc/distribution/app/agc-help-releaseapp-0000001146642648>
