# Recipe · 华为账号 / 第三方登录（指引型）

> verified_against: harmonyos-6.0.2-api22 · last sync 2026-05-07
>
> 关联规则：`AGC-RJ-001`（隐私政策）、`SEC-001..002`（不硬编码密钥 / 不打 token 日志）、`AGC-RJ-003`（实名认证 / 资质）

## 为什么这是"指引型"而非完整代码

登录涉及华为账号体系（`@kit.AccountKit` 的 AuthAccount） + AppGallery Connect 的 Auth 服务，**API 在 API 12 → 22 之间多次变化**：

- 旧版 `@ohos.account.distributedAccount`（已弃用）
- 中间版 `@hms.AccountKit`（部分场景）
- 当前版 `@kit.AccountKit` 的 `authentication.AuthRequest` + `authorization.AuthorizationRequest`

AI 训练数据里的写法**大概率是旧版**。直接给一份完整代码 = **大概率给的是已弃用 API**，会让用户编译失败 + 走弯路。

**正确做法**：从官方文档 + AGC 控制台拿当前版本 SDK，按下面"约束 + 步骤"走。

## 约束（必须遵守）

1. **隐私政策必须在登录前出现并被同意**（`AGC-RJ-001`）
2. **不要硬编码 client_id / app_secret**（`SEC-001`）
3. **不要在日志中打 token**（`SEC-002`）
4. **登录失败必须有 UI 提示 + 重试入口**（`AGC-RJ-018`）
5. **token 持久化必须用 EncryptedPreferences**，不用普通 Preferences
6. **退出登录必须真的清除本地凭证**（卸载残留 → `AGC-RJ-019`）

## 步骤

### 1. AGC 应用启用 Auth 服务

1. 登录 <https://developer.huawei.com/consumer/cn/service/josp/agc/>
2. 你的应用 → 增长 → **Auth Service** → 开启
3. 启用要支持的方式：华为账号 / 手机号 / 邮箱 / 第三方（微信 / QQ / 微博）等

### 2. 下 `agconnect-services.json`

AGC 控制台 → 项目设置 → 下载 `agconnect-services.json`，放到 `entry/` 目录。

### 3. 装 SDK

```json5
// oh-package.json5
{
  "dependencies": {
    "@hw-agconnect/auth": "latest",
    "@hw-agconnect/core": "latest"
  }
}
```

跑 `ohpm install`。本仓库的 `tools/check-ohpm-deps.sh` 会校验包名真实存在（防 AI 编 `@ohos/agconnect-auth` 这种伪包）。

### 4. 必读官方文档（按你要的登录方式选）

- **华为账号 SSO**：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references/auth-service-sso>
- **手机号一键登录**：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references/auth-service-quick-login>
- **第三方登录（微信 / QQ）**：各家 SDK 自己提供（百度地图 SDK skill 是参考；微信 / QQ 鸿蒙 SDK 见各开放平台）
- **本地用户名密码 + AGC 自有体系**：<https://developer.huawei.com/consumer/cn/doc/harmonyos-references/auth-service>

### 5. 隐私同意流程参考代码

见 `07-publishing/checklist-2026-rejection-top20.md` `AGC-RJ-001` 的最小代码片段（持久化首次同意）。

## 反模式（钩子 / review 会命中）

```typescript
// ❌ SEC-001: 硬编码
const APP_SECRET = 'abc123def456ghi789...';

// ❌ SEC-002: 用 %{public} 输出 token
hilog.info(DOMAIN, 'auth', 'token=%{public}s', token);

// ❌ AGC-RJ-001: 跳过隐私同意直接登录
async aboutToAppear() {
  await this.signIn();   // 用户都还没看过隐私政策
}

// ❌ 卸载残留：用普通 Preferences 存 token
await prefs.put('token', token);   // 应该用 EncryptedPreferences
```

## 完整范例放哪里

**等你跑通过一次后，可以贡献回本仓库**——欢迎 PR：

- 加 `samples/templates/login/<具体方式>/`
- README 顶部标 `verified_against: harmonyos-X.Y.Z-apiNN`
- 引用具体规则 ID
- 不要复制 SDK 内部细节，只给"调用骨架 + 关键约束"

详见 [`CONTRIBUTING.md`](../../../CONTRIBUTING.md)。
