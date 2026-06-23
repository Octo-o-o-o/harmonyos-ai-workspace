# Recipe · HUKS 加密的本地敏感数据存储（最小可用）

> 把 API key、refresh token、device id 等敏感字符串本地落盘的安全方式：`@kit.ArkData` `preferences` 存包装值 + `@kit.UniversalKeystoreKit` (HUKS) AES-256-GCM 加密。
>
> **真实出处**：OctoDesk Mobile 的 `SecureStore.ets` 简化版。
>
> verified_against: harmonyos-6.0.2-api22

## 什么时候用

- 落盘 OpenAI API key / 应用自身的 refresh token / 用户敏感凭据
- 上架 AGC 审核 `AGC-RJ-019`（"用户敏感数据未加密"）的合规要求
- 需要"卸载后即丢失"语义（HUKS 数据随 app 卸载自动清理，且不进 backup）

## 什么时候**不要**用

- 存大块结构化数据（聊天历史、附件等）→ 用 `relationalStore` + 数据库 key 用 HUKS 包
- 临时 session-only 数据 → 内存里 + AppStorage 即可，不需要落盘
- 非敏感配置（主题色、字号偏好）→ 直接 `preferences` 明文

## 约束（必须满足）

1. **HUKS key 必须懒生成**——首次 `set()` 时检查并生成；不要在 app 启动时一次性建（用户卸载/重装会丢密钥，进而导致 unwrap 失败）。
2. **GCM 模式用 NONCE + 认证 tag**——本 recipe 用 12 字节 CSPRNG nonce（`HUKS_TAG_NONCE`，**不是** IV）+ 显式 16 字节认证 tag（`HUKS_TAG_AE_TAG`），版本化封套 `gcm2|nonceHex|tagHex|cipherHex`。tag 返回位置不固定（独立 property 或追加在 outData 尾部），两者都要兜，否则换 ROM / API 版本可能解不开。
3. **`huks.deleteKeyItem` 必须包在 try/catch** 里——key 不存在会抛错，wipeAll 需要幂等。
4. **取 UIAbilityContext 不能走 AppStorage.get<UIAbilityContext>**——HarmonyOS 6.x 起 `varValueCheckFailed`；本 recipe 用 module-level singleton 模式存。
5. **不要在 ArkUI 组件 `aboutToAppear` 里同步调用 set/get**——HUKS 涉及 IPC，必须 `await`。
6. **错误码必须显式 `as BusinessError`** 处理，否则 `e.code` 是 undefined。

## 集成步骤

1. 把 `SecureStore.ets` + `RuntimeRegistry.ets` 复制到 `entry/src/main/ets/security/` 与 `entry/src/main/ets/runtime/`
2. 在 `EntryAbility.onCreate` 里**注册 context**（一次性）：

```typescript
import { setUIAbilityContext } from '../runtime/RuntimeRegistry'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    setUIAbilityContext(this.context)
  }
}
```

3. 业务调用：

```typescript
import { HuksWrappedPreferenceStore } from './security/SecureStore'

const store = new HuksWrappedPreferenceStore()

// 落盘
await store.set('openai.api.key', 'sk-...')

// 读取
const key = await store.get('openai.api.key')   // string | null

// 删除单条
await store.wipe('openai.api.key')

// 清空所有（包括 HUKS key）
await store.wipeAll()
```

## 验证

```bash
bash tools/hooks/lib/scan-arkts.sh SecureStore.ets RuntimeRegistry.ets
# 期望：无 STATE-002 / ARKTS-016 / SEC-* 命中

hvigorw codeLinter
# 期望：无 arkts-no-* 报错

# 真机/模拟器验证：set → 重启 app → get 能拿到值
# 卸载 → 重装 → get 应返回 null（HUKS key 不在了，数据失效）
```

## 反模式（AI 常踩）

- ❌ `AppStorage.setOrCreate('uiAbilityContext', this.context)` — HarmonyOS 6+ varValueCheckFailed
- ❌ AES key 在 app 内硬编码 / 用 `crypto.subtle` 自己加密 — 卸载残留 + key 泄露风险
- ❌ 用 base64 编码当 "加密" — 上架审核会拒
- ❌ `huks.deleteKeyItem` 不包 try/catch — key 不存在抛错导致整个 wipeAll 失败
- ❌ 把敏感数据存 `@StorageProp` / `@StorageLink` 持久化 — 明文写到磁盘

## 扩展点

OctoDesk 真实工程在此骨架上加了：

- **多 alias 隔离**：refresh token / device id / 其他凭据用不同 HUKS alias，单条泄露不影响全部
- **device-binding**：HUKS 选项里加 `HUKS_TAG_USER_AUTH_TYPE`，要求生物识别才能解（业务侧选用）
- **wipeAll 不删 device id**：保留设备身份，只清用户级数据
- **跨平台对齐**：iOS Keychain / Android Keystore 也实现同样的 `SecureStore` 接口
