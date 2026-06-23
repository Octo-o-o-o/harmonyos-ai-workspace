# Bridge Integration Pitfalls — HarmonyOS Web Bridge + 跨端原生外壳

> **场景**：Native Shell + WebView 业务区的混合架构。三端外壳（iPadOS WKWebView / Android System WebView / HarmonyOS ArkWeb）共用 JSON envelope 协议时常踩的接线层坑。本文偏 HarmonyOS NEXT 视角，跨端注意点单独标注。
>
> **配套规则**：`tools/hooks/lib/scan-arkts.sh` 的 `SEC-001` / `SEC-002` / `CSPRNG-001` / `ARKTS-DEPRECATED-PICKER` 已覆盖部分；本文档讲 **scanner 抓不到的"接线层"陷阱**。
>
> **配套样例**：`samples/templates/web-bridge-h5-shell/`（最小可跑骨架）。

## 1. Capability 握手必须 fail-closed（最常见的"看似在跑"bug）

### 陷阱

外壳暴露的 `BridgeCapability` enum 是声明，**真实接通的 handler 是另一回事**。两者一旦 drift（enum 里有但 handler 没注册，或 handler 注册了但 handshake 没返 granted），表现是：

- WebView 业务区调 `bridge.invoke('share', ...)` 拿到 timeout 或静默 noop
- 用户操作没反应、AI agent 抓 log 看不到错误
- 真机灰度才暴露，单元测试覆盖不到

### 标准做法

握手返回的 `granted` 列表**必须由 handler 注册表派生**，而不是从 enum 派生：

```typescript
// ❌ 反模式：从 enum 直接生成 granted
const granted: BridgeCapability[] = Object.values(BridgeCapability)

// ✅ 正确：从真实接通的 handler 集合派生
const HANDLERS: Map<BridgeMessageType, (payload: ESObject) => Promise<ESObject>> = new Map()
HANDLERS.set('sse.start', handleSseStart)
HANDLERS.set('storage.get', handleStorageGet)
// ...

const granted: BridgeCapability[] = []
if (HANDLERS.has('sse.start')) granted.push(BridgeCapability.SSE)
if (HANDLERS.has('storage.get')) granted.push(BridgeCapability.SECURE_STORE)
// ...
```

未接通的 capability 必须显式 `rejected` + reason，让业务区**早失败、不要兜底假装支持**：

```typescript
return {
  granted,
  rejected: BridgeCapability.values()
    .filter(c => !granted.includes(c))
    .map(c => ({ capability: c, reason: 'handler-not-registered' })),
}
```

业务区 JS 端拿到 rejected list 后该禁用对应入口（按钮置灰 + 引导用户升级 app），**不允许带病调用**。

### 进阶：三端 granted 集合的跨平台一致性

混合架构常踩的另一个变体：三端各自维护一份"granted constant"，结构上是对的（每端的 granted 都由真实 handler 派生），但**三端的真实 handler 集合不一致**——iOS 接通了 `share`，Android / HarmonyOS 没接。结果业务区在 iOS 上能用、在 Android 上拿到 `CAPABILITY_UNAVAILABLE`，调试时归因极其困难（业务侧"我明明 granted 收到了 share"）。

修复模式（来自 2026-05 一个下游 macOS/iPadOS/Android/HarmonyOS 四端套件的 N3 实战）：

1. **三端各自的 granted constant 单独写**（不强制共享代码——native 语言不同）
2. **加一个跨平台 lint 脚本**，regex 解析三端源文件 + 比较集合相等：

   ```bash
   # 伪代码 - 实际脚本见下游项目 scripts/check-native-capability-coherence.cjs
   contract_enum   = parse z.enum(...) from shared/contracts/native-shell.ts
   ios_granted     = grep .swift kOctoDeskBridgeShellCapabilities
   android_granted = grep .kt   BRIDGE_SHELL_CAPABILITIES + map BridgeCapability.<name>
   harmony_granted = grep .ets  SHELL_CAPABILITIES + resolve UPPER_SNAKE → camelCase
   assert ios_granted == android_granted == harmony_granted ⊆ contract_enum
   ```

3. **PR gate 跑此脚本**，三端漂移立即在 CI 报错

4. **`share` / `haptic` / `notifications` 等"placeholder capability"** 必须从 granted set 显式剔除——即便 enum 里保留位 + dispatcher 显式 fallthrough `CAPABILITY_UNAVAILABLE`，granted 里也**不能**包含

要点：scanner 抓不到的是"三端代码在各自正确，但跨端不一致"这种 cross-cutting bug；只能用跨平台脚本守门。

### 跨端注意

- **Android**：`AndroidX WebKit WebMessageListener` 是唯一允许的通道，**禁止回退到 `addJavascriptInterface`**——后者 historical JS-to-Java reflection 攻击面巨大。设备不支持 `WebMessageListener` 时 fail-closed 阻断 UI、引导用户升级 System WebView。
- **iOS**：`WKScriptMessageHandlerWithReply` 在 iOS 14+ 才有同步回执；旧版需要 promise polyfill 跨 callback。
- **HarmonyOS**：`Web` 组件的 `javaScriptProxy` 在 ArkWeb 6.1+ 稳定，但**生命周期绑定要在 `aboutToAppear()` 完成、`loadUrl()` 之前**（见 §2）。

## 2. `javaScriptProxy` / `WebMessageListener` 生命周期顺序

### 陷阱

ArkWeb 的 `javaScriptProxy` 必须在 Web 组件 build 之前注册；如果在 `onPageBegin` 或 `onLoadIntercept` 回调里"懒"注册，业务区第一次握手会 race 失败 —— 表现是页面看似空白、控制台看不到 bridge 注入。

### 标准做法

```typescript
@Component
struct WebViewHost {
  private controller: webview.WebviewController = new webview.WebviewController()
  private proxy: BridgeJavaScriptProxy = new BridgeJavaScriptProxy(this.controller)

  aboutToAppear(): void {
    // 在 build() 之前完成 controller / proxy 准备
    this.proxy.attach()
  }

  build() {
    Web({ src: this.bundleUrl, controller: this.controller })
      .javaScriptAccess(true)
      .javaScriptProxy({
        object: this.proxy,
        name: 'appBridge',
        methodList: ['handleEnvelope'],
        controller: this.controller,
      })
      .onPageBegin(() => {
        // 此时 proxy 已注入到 page world，可以握手
      })
  }
}
```

**两个常见踩坑**：

1. **`methodList` 必须显式列出**真实暴露的方法名。不要写 `['*']`——不仅 ArkWeb 不支持，写了也会被静默忽略导致 page world 调不到。
2. **proxy 实例不能在 `build()` 里 `new`**：每次重渲会创建新实例，旧 proxy 还挂在 page world 上，引用错乱。把 `new` 提到 `@State` 或 class 字段。

### 跨端注意

- **Android**：handler 名（`addWebMessageListener` 的 `jsObjectName`）一旦定下来不能改 —— page world 的 JS 已经 hardcode 这个名字。改名等于断 bridge。
- **iOS**：`WKUserContentController` 的 message handler 注册时机也是 `viewDidLoad` 之前，否则首屏握手会丢。

## 3. Mutating messages 必须带 `idempotencyKey`

### 陷阱

业务区因为 web→native callback 没回执而**重发同一条变更消息**（典型场景：用户来回切应用，IPC pending、UI 假死再点击）。如果 native 端不去重，会重复执行：

- `email.send` 重复发邮件
- `storage.set` 覆盖中间状态
- `outbox.enqueue` 重复入队

### 标准做法

定义一个 `BRIDGE_MUTATING_TYPES` 白名单（哪些消息会改持久状态），dispatcher 入口拒绝不带 `idempotencyKey` 的变更请求：

```typescript
const BRIDGE_MUTATING_TYPES: BridgeMessageType[] = [
  'storage.set', 'storage.wipe',
  'email.send', 'outbox.enqueue',
  'auth.login', 'auth.logout',
  'upload.start', 'upload.cancel',
  'folder-import.refresh', 'folder-import.release',
]

function dispatchEnvelope(env: BridgeEnvelope): void {
  if (BRIDGE_MUTATING_TYPES.includes(env.type) && !env.idempotencyKey) {
    return reject(env, BridgeErrorCode.MISSING_IDEMPOTENCY_KEY)
  }
  // 用 LRU<idempotencyKey → result> cache 去重
  const cached = idempotencyCache.get(env.idempotencyKey)
  if (cached) return reply(env, cached)
  // ...
}
```

cache TTL 看业务：上传断点续传可能要几小时；登录请求几分钟够了。

### 附：指向其它消息的操作（cancel / ack / retry）取消目标走 payload，别用信封 id 兜底

`sse.cancel` / `upload.cancel` 这类"我要取消**另一条**消息"的操作有个隐蔽坑：cancel 这条 envelope **自己是一条新消息、有自己的新 `id`**。如果取消目标用 `envelope.correlationId ?? envelope.id` 兜底，一旦 `correlationId` 为空就 fallback 到 cancel 信封自己的 id → 去"取消"一个根本不存在的流，真正该停的原始流（`SSE_START` 那条）没被取消，继续跑。

**标准做法**：取消目标从 **payload 显式解码**，envelope 信封 id 只作 legacy 兜底：

```typescript
if (envelope.type === BridgeMessageType.SSE_CANCEL) {
  const req = parseSseCancelRequest(envelope.payload)   // payload 里显式带 correlationId
  const correlationId = req === null
    ? (envelope.correlationId ?? envelope.id)            // legacy 兜底（次选）
    : req.correlationId                                   // 主路径：payload 优先
  this.sseManager.cancel(correlationId)
}
```

通用 bridge 协议设计教训（三端同犯），归根结底"信封 id（消息身份）≠ 业务关联 id（指向谁）"，两者不能混用兜底。反哺溯源 OctoDesk N5 · `16db3e689`。

## 4. Envelope schema validation — 不要信任 page world

### 陷阱

ArkTS 端拿到 stringified JSON 后 `JSON.parse()` 得到 `Object`，然后**强转成业务接口直接用字段**。一旦 page world 的代码因 hot-reload / 旧版本 / 第三方 webview 嵌套而发出畸形 envelope，ArkTS 端：

- 字段类型不对：`payload.size` 期望 `number` 实际 `'large'`
- 必填缺失：`messageId` 是 undefined，回执 routing 失败
- 类型 unsafely cast 后下游 `await fileio.write(payload as ESObject)` 直接崩

### 标准做法

ArkTS 没有 Zod，但可以手写 `validateBridgeEnvelope(raw: string): BridgeEnvelope | null`，逐字段 typeof / instanceof 检查 + 范围校验，失败一律 reject 不进 dispatcher。如果你的项目在 web 端用 Zod / OpenAPI / TypeBox 等定义了 envelope schema，ArkTS 端按字段一一镜像即可（顺序 + 类型 + optional/required + 范围），这样 schema 改动两端同步。

**反模式：`as BridgeEnvelope` 强转**。ArkTS 编译过不代表 runtime 安全。

## 5. 敏感字段在 hilog / console 里 leak（与 SEC-002 联动）

scanner 已覆盖 `hilog.X(domain, tag, '%{public} ...', token)` 的明显泄漏。但 bridge 场景额外要注意：

- **dispatcher 入口 dump envelope 调试**：开发期 `hilog.info(0, 'Bridge', '%{public}s', JSON.stringify(env))` 会把整条 envelope 包括 `accessToken` / `refreshToken` 打出来。改 `%{private}` 或在 dump 前白名单字段。
- **错误回执原样回 raw error**：`reject(env, e.message)` 可能把 `Authorization: Bearer eyJxxx` 暴露给 page world JS，被 sourcemap / 截屏抓到。错误对象进 page world 前要 sanitize。

## 6. Picker / 文件类 capability —— 一次性 vs watched，别混

### 陷阱

桌面端用 chokidar watched folder + 自动 FTS5 索引；移动端**不要复刻这套**。HarmonyOS picker（`@kit.MediaLibraryKit` 的 `photoAccessHelper.PhotoViewPicker`，**不是已废弃的 `picker.PhotoViewPicker`**——见 `ARKTS-DEPRECATED-PICKER` 规则）是用户显式授权的 one-shot URI，离开 picker 后 OS 立刻回收权限：

```typescript
// ✅ 正确：一次性 picker
const picker = new photoAccessHelper.PhotoViewPicker()
const result = await picker.select({ maxSelectNumber: 5 })
// result.photoUris 只在本次会话有效；之后想再读必须再次 picker
```

**不要**：
- 把 picker 返回的 URI 缓存到 Preferences 想着"下次再读"——大概率失效
- 在后台 task 里"轮询新文件"——这是桌面 watched folder 思维，移动端没有合法路径

如果真要"用户授权的文件夹后续可读"，走 Folder Import R1 受限路径 + Bridge v1.1，**只支持手动刷新，不支持后台监听**。

## 7. CSPRNG —— 与 `CSPRNG-001` scan-arkts 规则配套

任何加密 / nonce / IV / signature 路径都必须用 `cryptoFramework`：

```typescript
import { cryptoFramework } from '@kit.CryptoArchitectureKit'

const random = cryptoFramework.createRandom()
const nonce: Uint8Array = (await random.generateRandom(12)).data
// AES-GCM 12-byte nonce
```

`Math.random()` 在 ArkTS 移动端**任何**加密用途都是 hard fail。AES-GCM 一次 nonce 撞车 = 完全 break；HMAC 用 `Math.random()` 作 key 是无意义的。这条规则由 `CSPRNG-001` scan 抓覆盖（路径含 `security/` 或文件含 cryptoFramework / nonce / aesGcm / huks 关键字时升级到 High）。

> **OAuth 2.0 PKCE 是 CSPRNG-001 最容易忘的真实子场景**：RFC 7636 §4.1 要求 `code_verifier` 来自 CSPRNG。`Math.random()` 的 xorshift128+ 状态可从几次输出反推，攻击者可预计算 verifier 并截获授权流。正确写法（ArkTS）：
>
> ```typescript
> const data = cryptoFramework.createRandom().generateRandomSync(32).data
> const verifier = base64UrlEncode(data)  // RFC 7636 base64url
> ```
>
> 若 cryptoFramework 不可用，应 `throw` 而非静默 fallback —— "弱 PKCE 总比没 PKCE 好" 是错的，silent downgrade 会让客户端长期处于可攻击状态而无告警。

> **HUKS AES-GCM 用 `HUKS_TAG_NONCE` 而非 `HUKS_TAG_IV`**：HUKS 官方示例两个 tag 都出现过（CBC/CTR 用 IV、GCM 用 NONCE + AE_TAG），AI 极易混。GCM 下 nonce 重用比 CBC 的 IV 重用**更致命**——直接泄漏认证密钥流、可伪造密文。`CSPRNG-002` 规则已同时覆盖 `HUKS_TAG_IV` 与 `HUKS_TAG_NONCE`；GCM 完整封装范式（NONCE + AE_TAG 双位置兜底 + 版本化封套）见 §8 末「进阶」。

## 8. Token / SecureStore 写入原子性（先持久化、再 fire listener）

### 陷阱

跨端 `AuthController` 常见反模式：登录 / refresh 成功后**先**调 `storeAccessToken`（写内存 + fire `tokenChangeListener`），**再**写 refresh token 到 SecureStore（HUKS / Keychain / EncryptedPreferences）。Listener 经 bridge fan-out 立刻把 `auth.access_token.set` 推到 WebView，React 业务区把用户当成"已登录"。

如果**之后**的 SecureStore 写入失败（HUKS session 失败、Keychain entitlement 异常、Android KeyStore 损坏、磁盘满）：

- 当前会话 access token 仍然活的，业务区按"已登录"工作
- refresh token 没写盘，下次启动无法 refresh → 静默退出
- 同时 native panel 弹"登录失败"红条
- 两个状态**矛盾**且**无法在客户端调和**，用户体验是"明明登成功了，重启就完了"。需要手动 wipe 才能恢复

### 标准做法

把顺序倒过来：**SecureStore 写入在前**（能 throw，没有副作用），**`storeAccessToken` 在后**（只写内存 + fire listener，假定永远成功）：

```typescript
// ✅ 正确顺序
await this.secureStore.set(REFRESH_TOKEN_KEY, outcome.refreshToken)  // 先持久化
this.storeAccessToken(outcome.accessToken, outcome.expiresInMs)       // 后通知

// ❌ 反模式
this.storeAccessToken(outcome.accessToken, outcome.expiresInMs)       // listener 已 fire
await this.secureStore.set(REFRESH_TOKEN_KEY, outcome.refreshToken)   // 一旦 throw 就矛盾
```

### 跨端注意

这是**纯接线层 bug，scanner 抓不到**，但**三端都会犯**。代码 review 时把 "`secureStore.set` 必须在 `storeAccessToken` 之前" 写成显式 comment，并在 design doc 留 file:line 引用，避免 copy-paste 时被改回。同样适用于：

- iOS: `Keychain.setItem(...)` 在 `storeAccessToken(...)` 之前
- Android: `EncryptedSharedPreferences.edit().putString(...).commit()` 在 `tokenChangeListener.fire(...)` 之前
- HarmonyOS: `huks.set(...)` 或 HUKS-wrapped `preferences.put(...)` 在 fire listener 之前

### 进阶：native-only 凭据 key 必须对 page world fail-closed（三端一致）

`SecureStore` 经 bridge 暴露 `storage.get` / `storage.set` 给 WebView（page world）做通用 KV 时，**最敏感的几把 key 绝不能让 page world 读写**：refresh token、device registration key。它们是"native 持有、JS runtime 永不接触"的契约——一旦 compromised page / 注入脚本能 `storage.get('<refreshToken-key>')`，等于把长期凭据交给了不可信的 web 层。

**陷阱**：三端各自实现 `storageGet/storageSet` 守卫，很容易**只在某一端**加 deny list（例如 iOS 拒了、Android/HarmonyOS 漏了），或**只拒 contract 命名漏掉原生命名**。真实分歧：device key 原生常量是 `octodesk.device.registrationKey`，refresh 是 `octodesk.auth.refreshToken`，而跨端契约里又有 `device.registration_key` / `auth.refresh_token` 两套命名 → 必须**两套 keyspace 都拒**。

**标准做法**：

- 把受保护 key 列表提到**共享契约**（`PROTECTED_NATIVE_ONLY_KEYS`），**同时含 contract 键与原生键**两种命名，三端各自的守卫从同一来源对齐。
- `storageGet` / `storageSet` 命中 → 返回 `CAPABILITY_UNAVAILABLE`（不是静默成功、不是空值）。
- **`storage.wipe` 例外**：partial session-reset 需要真正清掉原生 token，所以 wipe 路径**不**走这个 deny list（否则 token 永远清不掉）；只 get/set 拒，wipe 放行。注意 partial-wipe 的 scope 数组要**同时**列 contract 键与原生键，否则只清到空的 contract keyspace、原生 token 残留（实测过的 partial-wipe bug）。
- 加一个 CI gate（如 `check-native-capability-coherence`）断言**三端 storage-key 拒绝集合一致**——presence 检查只能防"漏一端"，更强的是 set-equality 防"某端多塞一把"。

**跨端注意**：纯接线层一致性 bug，scanner 抓不到。iOS `isProtectedAuthCredentialKey` / Android `isProtectedAuthCredentialKey` / HarmonyOS `isProtectedAuthCredentialKey` 三处必须 key 集合 byte-for-byte 相同；新增一把 native-only 凭据时，**先改共享契约再 fan-out**，别在某一端 inline 硬编码。反哺溯源 OctoDesk MOB-1（三端 refresh-token / device-key 守卫对齐）。

### 进阶：HUKS AES-GCM 封装范式（NONCE not IV · AE_TAG 双位置 · 版本化封套）

`SecureStore` 用 HUKS 包 AES-GCM 落盘敏感值时，有两个 OpenHarmony Keystore 框架**特有**的坑：

1. **GCM 用 `HUKS_TAG_NONCE`**（12 字节，CSPRNG），不是 `HUKS_TAG_IV`。nonce 必须 `cryptoFramework.createRandom().generateRandomSync(12)`（见 §7 / `CSPRNG-002`）。
2. **GCM 认证 tag（`HUKS_TAG_AE_TAG`，16 字节）返回位置不固定**：`finishSession` 可能把它作为独立的 `HUKS_TAG_AE_TAG` **property** 返回，**也可能直接追加在 `outData` 末尾**。健壮实现两者都兜，否则换个 ROM / API 版本就解不开：

```typescript
// 加密：优先从 properties 找 AE_TAG，找不到从 outData 尾部切 16 字节
let cipherBytes = result.outData
let aeTagBytes = findHuksBytesParam(result.properties, huks.HuksTag.HUKS_TAG_AE_TAG)
if (aeTagBytes === null && result.outData.length > GCM_TAG_BYTES /* 16 */) {
  const tagOffset = result.outData.length - GCM_TAG_BYTES
  cipherBytes = result.outData.slice(0, tagOffset)
  aeTagBytes  = result.outData.slice(tagOffset)
}
// 解密：把 AE_TAG 显式作为 property 传回
if (aeTagBytes !== null) {
  properties.push({ tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: aeTagBytes })
}
```

3. **版本化封套**：用 `gcm2|nonce|tag|cipher` 四段（带魔数前缀），解密时**保留对旧两段 `nonce|cipher` 的兼容**，已落盘数据平滑升级、不丢。

完整可跑骨架见 `samples/templates/huks-secure-store/`。反哺溯源 OctoDesk N5 · `3dbe1d42c`（harden native auth and server routing，SecureStore 迁 GCM NONCE/AE_TAG）。

## 9. HarmonyOS Pasteboard 提示时机 —— 不要 eager peek

### 陷阱

HarmonyOS 6.x 起 `pasteboard.getData()` / `getSystemPasteboard().getData()` **每次调用都会弹系统级 toast**（"应用正在读取剪贴板"），且应用无法关闭这个 prompt（设计如此，是 OS-level UX）。如果 native shell 在以下时机"eager peek" 剪贴板：

- App 启动 / cold-start 完成第一帧渲染前
- App 切回前台时（`onForeground` / `onWindowFocusChange`）
- WebView 业务区还没 mount 完时被 bridge 触发

用户会看到一个**没有任何上下文**的"读取剪贴板"提示。AGC 审核常以此为 P0 拒因（"非用户主动操作时读取剪贴板"），同时是 24h 留存的红线。

### 标准做法

把 pasteboard 调用门控在**显式用户操作**之后（点击按钮、扫码完成回调、用户输入触发的搜索等），且 native 端要主动过滤：仅返回符合预期格式的内容，绝不把整段剪贴板转给 WebView：

```typescript
// ✅ 正确：用户点了"粘贴配对码"按钮后才读
async handleUserPastePairingTicket(): Promise<string> {
  const board = pasteboard.getSystemPasteboard()
  const text = await board.getData()  // 此时系统 prompt 有明确语义
  const raw = await text.getPrimaryText()
  // 仅当看起来像 octodesk-pair://v1?t=... 才放行
  if (!raw.startsWith('octodesk-pair://')) return ''
  return raw
}

// ❌ 反模式：App 启动 / 前台切换时 peek
onForeground(): void {
  this.peekClipboard()  // ← 系统 prompt 在没有上下文的时机弹，用户/审核都会困惑
}
```

如果 native 想"自动识别用户复制了配对链接然后弹引导"，**用 share intent / App-Linking 而非剪贴板**：让分享方主动 `openLink(...)` 把链接送进来，比从剪贴板猜要干净。

### 跨端注意

- **iOS**：`UIPasteboard.general.string` 在 iOS 14+ 同样每次读都弹横幅，与 HarmonyOS 一致。
- **Android**：`ClipboardManager.getPrimaryClip()` 默认无 toast（部分厂商定制 ROM 有），但 Android 12+ App 前台读会被 system overlay 提示，规则同上。

## 10. App-Linking 双侧配置 + EntryAbility 双入口路由（HarmonyOS）

### 陷阱

`https://link.<domain>` 类深链接（含 OAuth callback / push deeplink / share link）在 HarmonyOS 上需要**三件事同时正确**：

1. **`apps/.../AppScope/well-known/harmony-app-linking.json`** 的 `components` 列出每条 path（这是上传到华为 Domain Verify 服务的清单）
2. **`apps/.../entry/src/main/module.json5`** 的 `skills.uris` 用 `pathStartWith` / `path` 显式列出（这是 OS-level intent filter）
3. **`EntryAbility.ets` 在 `onCreate` AND `onNewWant` 都做 dispatch**

很多 app 只配了上面 1 或 1+2，结果：

- 测试时点链接看似能拉起 app，**但 cold-start 路径不走 deeplink dispatcher**（`onCreate` 没读 `want.uri`），WebView 启动后停在首页
- 或者反过来：cold-start 走了，但 app 已经在前台时，`onNewWant` 没接，新链接被丢
- 或者 `harmony-app-linking.json` 列了 path 但 `module.json5` 没列，OS intent filter 不 match，Domain Verify 失败

### 标准做法

**三处必须同步**。下面是一个最小可跑骨架（OAuth callback + push + share 三类）：

```json5
// apps/<bundle>/AppScope/well-known/harmony-app-linking.json
{
  "applinking": {
    "apps": [{
      "appIdentifier": "<your-app-id>",
      "fingerprints": [],
      "components": [
        { "/": "/oauth/callback/*" },
        { "/": "/push/*" },
        { "/": "/share/*" }
      ]
    }]
  }
}
```

```json5
// apps/<bundle>/entry/src/main/module.json5
"skills": [{
  "actions": ["ohos.want.action.viewData"],
  "uris": [
    { "scheme": "https", "host": "link.<your-domain>",
      "pathStartWith": "/oauth/callback" },
    { "scheme": "https", "host": "link.<your-domain>",
      "pathStartWith": "/push" },
    { "scheme": "https", "host": "link.<your-domain>",
      "pathStartWith": "/share" }
  ]
}]
```

```typescript
// apps/<bundle>/entry/src/main/ets/entryability/EntryAbility.ets
onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
  // cold-start：want.uri 来自 OS 拉起时的 deeplink
  const uri = typeof want.uri === 'string' ? want.uri : ''
  if (uri.length > 0) this.dispatchInboundUri(uri)
}

onNewWant(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
  // warm-start：app 已在前台或后台，OS 用 onNewWant 投递新 deeplink
  const uri = typeof want.uri === 'string' ? want.uri : ''
  if (uri.length > 0) this.dispatchInboundUri(uri)
}

private dispatchInboundUri(uri: string): void {
  // 不要在这里直接 navigate WebView。先按 path 分类：
  //   /oauth/callback/* → OAuthPlugin.deliverCallback(uri)
  //   /push/* / /share/* → bridge.emitRouteDeeplink(uri)
  // OAuth callback 永远不应该走"通用 route.deeplink"，否则 WebView 路由会误处理。
  if (OAuthPlugin.parseCallbackUri(uri) !== null) {
    this.oauthPlugin.deliverCallback(uri)
  } else {
    this.bridge.emitRouteDeeplink(uri)
  }
}
```

### 深一层：OAuth callback 必须用外部 user-agent（RFC 8252）

OAuth 2.0 / OIDC 强制要求授权流走**外部 user-agent**（系统浏览器），不能用 ArkWeb / WebView 作 user-agent —— 否则一旦 ArkWeb renderer 被攻陷（XSS / hook），攻击者能 scrape 第三方登录表单。HarmonyOS 上正确做法是 `@kit.AbilityKit` 的 `UIAbilityContext.openLink(authorizationUrl)`，`appLinkingOnly` 留默认 `false`，让 OS 把 https URL 路由到用户的默认浏览器。然后通过 App-Linking 把 `/oauth/callback/*` 收回来。

另外两条防御：

- **路径 host 二次校验**：即使 OS 的 Domain Verify 已经 match 过 host，plugin 入口仍要 `expectedCallbackHost === 'link.<your-domain>'` literal 比较，防止 module.json5 误配额外 host 时的 cross-tenant 攻击
- **客户端 dedup ring**：把已 consume 的 `intentId` 持久化（plain preferences 即可，server-side 是权威，client-side 是 defense-in-depth），server 的 dedup 401 之前先在客户端 fail-closed

### 跨端注意

- **iOS**：等价文件是 `apps/ios/App/well-known/apple-app-site-association.json`，path 在 `components[].`/` 字段；project.yml 里 `applinks:link.<domain>`；`SceneDelegate.scene(_:openURLContexts:)` + `scene(_:continueUserActivity:)` 双入口。
- **Android**：等价文件是 `apps/android/app/.well-known/assetlinks.json`，path 必须**同时**在 `AndroidManifest.xml` 的 `<data android:pathPrefix=...>` 里 —— assetlinks 只授权 host，per-path 路由靠 manifest。`MainActivity.onCreate` + `onNewIntent` 双入口。

## 11. HMS ScanKit 接线层 trap（HarmonyOS）

### 陷阱

HMS ScanKit (`@kit.ScanKit`) 在 HarmonyOS NEXT 6.x 上有三个并存的踩坑面，AI 训练数据里几乎全是错的：

1. **`@kit.ScanKit` 直接 dynamic import 在某些镜像上拿到 undefined exports** —— 调用 `scanKit.scanBarcode.startScanForResult` 报"Cannot read properties of undefined"，模拟器多数 OK，真机不一致。**dual-import** 才稳：

   ```typescript
   const scanBarcodeMod: ESObject = await import('@hms.core.scan.scanBarcode')
   const scanCoreMod: ESObject = await import('@hms.core.scan.scanCore')
   const scanBarcode = scanBarcodeMod.default as ScanBarcodeApi
   const scanCore = scanCoreMod.default as ScanCoreApi
   ```

   由 `KIT-003` scan 抓覆盖。

2. **`ScanType.QRCODE` 在 HarmonyOS 6.x 已改名为 `QR_CODE`** —— 旧名是 `undefined`，传入 `options.scanTypes` 让 `startScanForResult` 以 `BusinessError code 401`（"Parameter check failed"）整体失败。AI 训练数据里几乎全用 `QRCODE`，必须显式覆盖。由 `KIT-004` scan 抓覆盖。

3. **`startScanForResult(context, options)` 的 `context` 必须是 page-bound `UIAbilityContext`** —— 也就是从 ArkUI `@Entry struct` 的 `aboutToAppear()` / `build()` 内调 `getContext(this) as common.UIAbilityContext` 得到的那个。Plugin 在 EntryAbility 的 `onCreate(want, launchParam, context)` 里拿到的"裸" `AbilityContext` 不带 page binding，传给 ScanKit 同样以 `code 401` 失败。**这条 scanner 抓不到**，是纯接线层 trap。

### 标准做法

在页面（`@Entry struct`）的 `aboutToAppear` 把 page-bound context 注册到一个 runtime registry，plugin 从 registry 取，不要从 EntryAbility 直接传：

```typescript
// pages/Index.ets
@Entry
@Component
struct Index {
  aboutToAppear(): void {
    const pageCtx = getContext(this) as common.UIAbilityContext
    setUIAbilityContext(pageCtx)   // 写入 runtime registry
  }
}

// scanner plugin
const pageCtx = getUIAbilityContext() ?? this.context   // 回退到裸 ctx 仅做兜底
const result = await scanBarcode.startScanForResult(pageCtx, options)
```

错误码到 bridge outcome 的映射（HarmonyOS 真实 BusinessError code）：

| code | 含义 | bridge outcome |
|------|------|---------------|
| `1000500001` | 相机权限被拒 | `permission_denied`（导引 `canOpenSettings: true`） |
| `1000500002` | 用户主动关闭扫码 UI | `cancelled` |
| `401` | 参数校验失败（多半是 ScanType 错 / context 错） | `unavailable`（写 hilog 含 raw error 便于排查） |

**HarmonyOS 不像 Android 有 `shouldShowRationale`**，相机权限被拒后只能引导用户去系统设置页 —— 所以 `canOpenSettings` 永远 `true`。

### 完整骨架

见 `samples/templates/scan-qrcode/`（含 plugin + page wiring + 错误码处理 + bridge outcome 序列化）。

## 12. ArkTS V1 禁 object literal → event payload "接线膨胀"

### 陷阱

ArkTS V1（HarmonyOS NEXT 默认）强 type-strictness：bridge event payload 不允许 object literal `{ correlationId, errorCode, ... }`，必须 `new BridgePayload()` 后逐字段赋值。结果是每个 `service.fail(...)` / `emit(error, ...)` 调用点都展开为 4-8 行：

```typescript
// ❌ 反模式 — 每个调用点重复
async startUpload(corrId: string, request: BridgeUploadStartRequestPayload): Promise<void> {
  if (!this.allowed(request.endpoint)) {
    const payload = new BridgeUploadErrorEventPayload()
    payload.correlationId = corrId
    payload.errorCode = 'BRIDGE.INVALID_PAYLOAD'
    payload.errorMessage = 'endpoint not allowed'
    payload.retryable = false
    this.emitError(payload)
    return
  }
  if (this.active.has(corrId)) {
    const payload = new BridgeUploadErrorEventPayload()
    payload.correlationId = corrId
    payload.errorCode = 'BRIDGE.NATIVE_FAILURE'
    payload.errorMessage = 'upload already running'
    payload.retryable = false
    this.emitError(payload)
    return
  }
  // ... 又重复一次 method 不支持 ...
  // ... 又重复一次 body 缺失 ...
}
```

OctoDesk UploadController 2026-05 audit 单文件 8 处 4 行模板（~32 行噪音），handler 主线逻辑被埋没。同款问题在 SSE / Picker / OAuth / Push 各 plugin 都会出现。

### 标准做法 —— per-service private builder helper

每个 service 内部抽 `private reportXxx(...)` / `private failAndXxx(...)` helper，把 `new` + 字段 assign + `emit` 收一处，调用点变 1 行 delegate：

```typescript
// ✅ service 内 private helper
private reportError(
  corrId: string,
  code: string,
  message: string,
  retryable: boolean,
): void {
  const payload = new BridgeUploadErrorEventPayload()
  payload.correlationId = corrId
  payload.errorCode = code
  payload.errorMessage = message
  payload.retryable = retryable
  this.emitError(payload)
}

// 已注册后失败需要清理表项 → 单独 helper, 命名反映状态
private failAndUnregister(
  corrId: string,
  code: string,
  message: string,
  retryable: boolean,
): void {
  this.reportError(corrId, code, message, retryable)
  this.active.delete(corrId)
}

// 调用点 5 行 → 1 行
async startUpload(corrId: string, request: BridgeUploadStartRequestPayload): Promise<void> {
  if (!this.allowed(request.endpoint)) {
    this.reportError(corrId, 'BRIDGE.INVALID_PAYLOAD', 'endpoint not allowed', false)
    return
  }
  if (this.active.has(corrId)) {
    this.reportError(corrId, 'BRIDGE.NATIVE_FAILURE', 'upload already running', false)
    return
  }
  // ...
}
```

### 谨防的边界

- **不要抽跨 service 通用 builder**：

  ```typescript
  // ❌ 反模式 — ESObject 泛型让 IDE / scan-arkts 失字段名 / 类型 narrow
  function reportBridgeError<T>(emit: (p: T) => void, P: new () => T, fields: Partial<T>) { ... }
  ```

  ArkTS V1 + ESObject 泛型 erase 后等于回到 untyped JS，调用方失字段拼写校验。**每个 payload class 各自的 service-local helper 是合理颗粒**。

- **保留语义命名差异**：`reportError` vs `failAndUnregister` 反映"未注册 / 已注册后失败"两态；不要强合并到一个名字。

- **不抽 success payload builder**：success 各 service 字段差异大（含 metadata / progress / nextCursor 等），强抽通常注释比代码长，per call-site 直接构造更清晰。

- **如果一个 service 同 payload 类型只用 1-2 处**：直接 inline，不抽 helper（抽是为消重复，1-2 处不算重复）。

### 配套样例

`samples/templates/error-event-builder/` — 最小可跑骨架，含 UploadController-style service 含 `reportError` + `failAndUnregister` 双 helper + 2 个不同状态的调用点。

## 13. 原生毛玻璃 / blur 只能做有界增强（HarmonyOS）

### 陷阱

ArkUI 的 `backdropBlur` / `backgroundBlurStyle` 看起来很接近 Web
`backdrop-filter`，AI 很容易把桌面玻璃效果原样搬进 HarmonyOS 原生外壳：

- 在 WebView 上层放一个半透明 ArkUI 卡片并直接 `backdropBlur(28)`
- 对可滚动列表、动态背景、多个嵌套卡片都开实时 blur
- 把 blur 半径做成 entrance 动画或跟随手势实时变化
- 没有低端机 / reduce-transparency / API guard fallback

结果通常不是"更接近桌面"，而是 RenderService / UI 线程逐帧开销上升，
真机滚动、弹窗开合或 WebView 合成时掉帧。更糟的是 ArkWeb 在部分设备上会
提升成独立原生图层，ArkUI 卡片可能压不住 WebView，blur 看似失效或被内容盖住。

### 标准做法

把原生 blur 当作**有界增强**，不是基础可用性依赖：

1. **API guard + 开关集中化**：封装 `supportsRealtimeBlur()`，同时检查
   target API、设备能力、低功耗 / reduce-transparency / 远程 kill switch。
2. **一次只开一个静态岛**：登录 / 设置这类 modal island 可以用固定半径；
   禁止在长列表、持续动画背景、嵌套 surface 上开 blur。
3. **不动画 blur 半径**：入口动效只做 opacity / scale / shadow；blur 半径固定。
4. **fallback 等价**：guard 失败时用同一套 token 的强玻璃填充、rim、sheen、
   shadow，不换品牌色、不降成随手的灰色块。
5. **WebView 先验证 z-order**：如果 blur 的背景是 ArkWeb，先在真机确认 ArkUI
   overlay 能盖住 WebView；不稳定时隐藏 / 暂停 WebView 或直接使用 opaque fallback。
6. **Profiler 证据进 PR**：至少记录开合弹窗时 UI/RenderService 帧耗时，确认
   60fps 预算（单帧约 16.6ms）内没有连续掉帧。

### OctoDesk Step 6 落地补充（2026-06-11）

OctoDesk / 千手 HarmonyOS 原生登录岛 + 设置岛迁 Soft Glass 时采用的生产约束：

- 颜色、rim、sheen、阴影、blur 半径全部来自 codegen 的 ArkTS token；`rgba(...)`
  在组件边界转换为 ArkUI `#AARRGGBB`，不在产品组件手抄色值。
- `supportsRealtimeBlur()` 集中在 theme/helper 层；主线仍是 API 22，API 24 Beta
  镜像只能做观察证据，不能驱动产品 API 选择。
- 登录 prompt 打开时隐藏 ArkWeb sibling，避免 WebView 提升为独立图层后盖住 ArkUI
  overlay；blur 只作用于 token 化 native backdrop。
- 登录岛与设置岛共用策略：最多一个静态 island、固定 radius、无 blur 半径动画；
  fallback 使用 `glass.surfaceStrong` + 同一套 rim/sheen/shadow，而不是降回旧品牌色。
- PR / step exit 必须带 light+dark 截图、真机或 emulator 设备信息、以及 UI /
  RenderService 帧耗时或同等性能证据；没有签名 `.p7b` / UDID 时，明确标记 signed
  install blocked，不伪造真机结论。

```typescript
const ENABLE_REALTIME_BLUR: boolean = true
const API_MAINLINE: number = 22

function supportsRealtimeBlur(): boolean {
  return ENABLE_REALTIME_BLUR && API_MAINLINE >= 9
}

// ✅ fallback 与 realtime 分支共享 token，不手写临时色
if (supportsRealtimeBlur()) {
  GlassIsland()
    .backdropBlur(28)
    .backgroundBlurStyle(BlurStyle.Thin, { scale: 0.2 })
} else {
  GlassIsland()
    .backgroundColor('#E6FFFFFF') // 例：由 token rgba 转成 #AARRGGBB
}
```

### 谨防的边界

- 不要把 `backdropBlur` 当作 CSS `backdrop-filter` 的逐像素等价替代。跨平台验收应是
  "角色等价 + 视觉意图一致 + 无障碍合格 + 平台例外登记"。
- 不要为了过视觉门禁手写产品色；颜色、rim、sheen、shadow 应来自设计 token 生成物。
- 不要在模拟器单帧看起来可用后跳过真机；WebView 合成和 GPU 负载差异主要在真机暴露。

## 14. WebView 前后台生命周期统一管理（HarmonyOS）

Native Shell + WebView 架构里"app 切后台"这件事 ArkWeb **不会自动处理**——JS 定时器继续跑、SSE 流继续收、原生心跳继续发。鸿蒙的 `UIAbility` 生命周期、ArkWeb 引擎、bridge 的 web 侧监听器是三个独立时钟，必须手动对齐。这一节是 OctoDesk N5（移动端 GA 前加固）的整段实战。

### 14.1 Ability 前后台 → `WebviewController.onActive/onInactive`（暂停 JS 定时器）

**陷阱**：`UIAbility.onBackground()` 触发时，ArkWeb 里 React 业务的 `setInterval` / 动画 / 轮询**照常运行**，后台持续吃 CPU 和电。很多人以为 WebView 会随 Ability 自动挂起——不会。

**标准做法**：`onBackground/onForeground` 显式转发到 `WebviewController.onInactive()/onActive()`——**只有这两个方法**会暂停/恢复 ArkWeb 的 JS 定时器与渲染。controller 引用集中登记到 registry（别让 EntryAbility 直接持有 `@Entry struct`）：

```typescript
// RuntimeRegistry.ets —— controller 引用集中登记
let webViewLifecycleController: webview.WebviewController | null = null
export function setWebViewLifecycleController(c: webview.WebviewController | null): void {
  webViewLifecycleController = c
}
export function pauseWebViewForBackground(): void {
  try { webViewLifecycleController?.onInactive() } catch (_e) { /* 冷启时 ArkWeb 可能未 attach */ }
}
export function resumeWebViewForForeground(): void {
  try { webViewLifecycleController?.onActive() } catch (_e) {}
}

// EntryAbility.ets
onBackground(): void { pauseWebViewForBackground(); this.setAppLifecycleState('background') }
onForeground(): void { resumeWebViewForForeground(); this.setAppLifecycleState('foreground') }

// WebViewHost：onControllerAttached 里 setWebViewLifecycleController(controller)；
// aboutToDisappear 里 onInactive() + setWebViewLifecycleController(null) 解绑防泄漏
```

约束：controller 只有 `onControllerAttached` 之后才可用；所有调用包 try-catch；`aboutToDisappear` 必须解绑 registry 引用置 null（否则对已销毁 controller 调用 / 引用泄漏）。

**鸿蒙特异性（强）**：三端对照最说明问题——**iOS WKWebView 根本没有 `pauseTimers` 等价能力**；Android 走 `ProcessLifecycleOwner` + `WebView.pauseTimers()`；鸿蒙独有 `UIAbility.onBackground` → `WebviewController.onInactive()` 这条链路。另外**别把"失焦"当"后台"**：下拉通知栏 / 多任务预览导致的 inactive ≠ 真后台，用 Ability 的 `onForeground/onBackground` 区分（14.3 的分级取消依赖这个语义）。

### 14.2 handshake-replay 不变量：native→web 状态事件不能比 bridge 监听器早

**陷阱**：app 启动早期 native 已经知道当前前后台 / 折叠态 / 断点，但 WebView 的 bridge listener 还没建好——这些在 handshake **之前**发出的 state-change 事件**没有接收方，直接丢失**。WebView 拿到缺省 / 过期状态，表现为"刚启动布局错乱""后台标志没生效"，偶发难复现。这是 Native Shell + WebView 的**结构性时序问题**。

**标准做法**：native shell 持续维护"当前状态快照"，在 **handshake 完成回调**里**强制重发**（`force` 绕过去重），lifecycle 与 window layout 都要 replay：

```typescript
// 发射带去重 + force 旁路
emitAppLifecycle(state: string, hint: string | null = null, force: boolean = false): void {
  if (!force && this.lastState === state && this.lastHint === hint) return
  this.lastState = state; this.lastHint = hint
  this.emitToJs(/* app.lifecycle event */)
}

// EntryAbility：握手完成后 setTimeout(0) 补发当前快照
this.bridgeRuntime.attachHandshakeCompletedHandler((): void => {
  setTimeout((): void => {
    this.emitCurrentAppLifecycle(true)          // force 重发 lifecycle
    this.windowLayoutObserver?.replayCurrent()  // 重放 window layout 快照
  }, 0)
})

// WindowLayoutObserver.replayCurrent()：有缓存重放缓存，无缓存现采一次
replayCurrent(): void {
  let payload = this.latestPayload
  if (payload === null) { payload = this.snapshot(); this.latestPayload = payload }
  this.emit(payload)
}
```

web 侧建**一个统一 store** 合并 native 信号 + document visibility fallback，所有后台策略消费同一来源，别各处自己解析生命周期。`onDestroy` 记得 `detachHandshakeCompletedHandler()` 解绑。

**鸿蒙特异性（模式通用、实现绑定鸿蒙 API）**："handshake 后 force-replay 当前状态"对任何 native-shell + webview 架构都成立（三端都做了），鸿蒙实现绑定 `UIAbility` 生命周期 + `WebviewController` + 握手回调。与 §2（`javaScriptProxy` 生命周期顺序）互补：§2 讲"proxy 要在 web 加载前 attach"，本节讲"proxy 建好之前发的事件会丢、要补发"。

### 14.3 后台分级 grace-cancel：inactive 不杀、background 宽限后才杀

**陷阱**：交互型 SSE 流（AI 回答）和 Desktop Remote 心跳在后台继续占网络 / CPU；但一进后台立刻 kill 也不对——用户短暂切走看一眼通知再回来体验很差，且鸿蒙网络栈 http 流不随 Ability 后台自动暂停。

**标准做法**：按生命周期**分级**——`inactive`（失焦）**不**取消；`background`（真后台）起**一次性宽限计时器**，到点**二次确认仍在后台**才 `cancelAll()`；任何回前台 / inactive 清掉计时器：

```typescript
const BACKGROUND_CANCEL_GRACE_MS: number = 20_000

handleAppLifecycle(state: string): void {
  this.lifecycleState = state
  if (this.backgroundCancelTimer !== null) {
    clearTimeout(this.backgroundCancelTimer); this.backgroundCancelTimer = null
  }
  if (state !== 'background') return                            // inactive / foreground 不取消
  this.backgroundCancelTimer = setTimeout((): void => {
    this.backgroundCancelTimer = null
    if (this.lifecycleState === 'background') this.cancelAll()  // 二次确认仍在后台
  }, BACKGROUND_CANCEL_GRACE_MS)
}
```

Desktop Remote 心跳配套：后台 `suspendForBackground()`（静默关 socket、保留 resume ticket），前台 `resumeFromBackground()` 复用既有 trusted-device resume 而非新建会话；前台**不自动续跑**已取消的答案（用户没在看时别偷跑）。

**鸿蒙特异性（中）**：`inactive vs background` 分级由鸿蒙 Ability 生命周期语义直接驱动；grace-cancel 思路通用，但接入点（`@kit.NetworkKit` http 流、Ability 生命周期）是鸿蒙的。

### 14.4 附带：`display.densityPixels` 不可靠时 fallback 要可观测

`display.getDefaultDisplaySync().densityPixels` 并非所有设备 / 时机都返回有效值，静默 fallback 到 2.0(xhdpi) 会让 dp 断点算错且无人知道。fallback 路径**用 `hilog.warn` 记一次**（`didLog` 去重防刷屏），把"我在用兜底值"变成可观测信号：

```typescript
let didLogDensityFallback = false
function densityFactor(): number {
  try {
    const d = display.getDefaultDisplaySync().densityPixels
    if (Number.isFinite(d) && d > 0) return d
  } catch (_e) { /* fall through */ }
  if (!didLogDensityFallback) {
    didLogDensityFallback = true
    hilog.warn(DOMAIN, 'WindowLayoutObserver', 'densityPixels unavailable; fallback 2.0')
  }
  return 2.0
}
```

> 反哺溯源 OctoDesk N5（移动端 GA 前加固）· `b714e653c`（后台暂停 WebView 定时器）/ `0b7bab762`（app.lifecycle 统一发射 + handshake replay）/ `bdcc6d686`（后台流与心跳 grace-cancel）/ `d49c97971`（form-factor + densityPixels）。

## 15. ArkWeb 文件下载：data-URL 拦截 + cancel 误报失败（HarmonyOS）

**陷阱**：WebView 里点下载一个 `data:...;base64,...` URL（典型：桌面远程预览把文件生成成 data-URL 交前端下载），ArkWeb 的 `WebDownloadDelegate` **不原生处理 `data:` 协议**——native 下载走不通。而且若为接管下载调 `item.cancel()`，**`cancel()` 会触发 `onDownloadFailed` 回调**，用户看到莫名其妙的"下载失败"toast。

**标准做法**：`onBeforeDownload` 里 sniff `data:` → 记下这个 download 的 guid（标记为"我主动取消的"）→ `item.cancel()` → 自己 base64 解码 + `fileIo` 写盘；`onDownloadFailed` 里识别 guid 把误报吞掉：

```typescript
private downloadDelegate: webview.WebDownloadDelegate = new webview.WebDownloadDelegate()
private manualDownloadGuids: Set<string> = new Set<string>()

this.downloadDelegate.onBeforeDownload((item: webview.WebDownloadItem): void => {
  if (item.getUrl().startsWith('data:')) {
    this.rememberManualDownload(item.getGuid())     // 标记主动取消
    item.cancel()
    void this.writeDataUrlToDisk(item.getUrl(), sanitizeSuggestedFileName(item.getSuggestedFileName()))
  }
})
this.downloadDelegate.onDownloadFailed((item: webview.WebDownloadItem): void => {
  if (this.consumeManualDownload(item.getGuid())) return   // 是我取消的，吞掉失败通知
  // ... 真实失败才提示
})
```

要点：
- **大小上限**：base64 解码前先估算解码后字节数，超过 `MAX_DATA_URL_DOWNLOAD_BYTES`（如 32MB）直接拒，别把整段 data-URL decode 进内存。
- **文件名 sanitize**：data-URL 的 `name=` / `filename=` meta 不可信，过 `sanitizeSuggestedFileName`（拒路径分隔符 `/ \`、控制字符、`..`），再 `fileIo.openSync(CREATE | TRUNC | READ_WRITE)` + `writeSync`，`finally closeSync`。
- **`manualDownloadGuids` 若是 ArkUI 状态记得 copy-on-write**（见 `STATE-009`）——`Set.add/.delete` 原地变更不被观察；OctoDesk 把它改成 `const next = new Set(this.set); next.add(g); this.set = next`。

**鸿蒙特异性（强）**：ArkWeb `WebDownloadDelegate` 对 data-URL 的处理缺口、`cancel()` 触发 `onDownloadFailed` 都是 ArkWeb 具体行为；Android WebView `DownloadListener` / iOS WKWebView 的下载语义完全不同。

> 反哺溯源 OctoDesk N5 · `3f4df3578`（harden desktop remote file previews）。

## 16. 反检查清单（上 PR 前过一遍）

- [ ] handshake 的 `granted` 来自 handler 注册表，不是 enum
- [ ] `BridgeCapability` enum 新增条目都有对应 handler，或者明确 reject + reason
- [ ] `javaScriptProxy` 在 `aboutToAppear()` 之前完成 attach、proxy 实例不在 `build()` 内 new
- [ ] mutating message 都在 `BRIDGE_MUTATING_TYPES` 白名单内、入口拒绝缺 `idempotencyKey`
- [ ] envelope 走过 `validateBridgeEnvelope`，未通过的 reject 不 dispatch
- [ ] hilog dump / 错误回执的字段过滤过 token / password / refreshToken
- [ ] picker URI 不进任何缓存 / 后台 task；要后续读改走 Folder Import
- [ ] 加密路径全 `cryptoFramework`，scanner 的 `CSPRNG-001` exit 0
- [ ] PKCE / token / nonce / IV 来源 `cryptoFramework.createRandom`，不退路到 `Math.random`
- [ ] **登录 / refresh：`secureStore.set(refresh)` 在 `storeAccessToken` 之前**（§8）
- [ ] pasteboard 仅在显式用户操作回调内读，不在 `onForeground` / `aboutToAppear` 等"被动"时机调（§9）
- [ ] App-Linking 三处同步：`harmony-app-linking.json` ↔ `module.json5` ↔ `EntryAbility.onCreate` + `onNewWant` 双入口（§10）
- [ ] OAuth callback 走系统浏览器（`UIAbilityContext.openLink`），不在 ArkWeb 内开授权页（§10）
- [ ] HMS ScanKit dual-import + `QR_CODE` 新名 + page-bound `UIAbilityContext`（§11）
- [ ] 原生 blur 有 API guard、单岛范围、opaque fallback、真机 Profiler/截图证据（§13）
- [ ] `addJavascriptInterface` / 已废弃 `picker.PhotoViewPicker` / `decodeWithStream` 全 0 命中（scanner 覆盖：`ARKTS-DEPRECATED-PICKER` / `ARKTS-DEPRECATED-DECODE`）
- [ ] WebView 前后台：`UIAbility.onBackground/onForeground` 转发 `WebviewController.onInactive()/onActive()`，`aboutToDisappear` 解绑 controller（§14.1）
- [ ] native→web 状态事件（lifecycle / window layout）在 handshake 回调里 force-replay 当前快照，`onDestroy` 解绑 handshake handler（§14.2）
- [ ] 后台 SSE / 心跳分级取消：inactive 不杀、background 宽限后二次确认才 `cancelAll()`（§14.3）
- [ ] `data:` URL 下载手动拦截（cancel + base64 + fileIo + 大小上限 + 文件名 sanitize），`onDownloadFailed` 吞掉主动 cancel 的误报（§15）
- [ ] cancel / ack 类操作取消目标走 payload，不用 envelope 信封 id 兜底（§3）
- [ ] HUKS AES-GCM 用 `HUKS_TAG_NONCE` + AE_TAG 双位置兜底 + 版本化封套（§8）

## 17. 相关 scan-arkts 规则

| 规则 ID | 严重度 | 覆盖什么 |
|--------|--------|---------|
| `SEC-001` | High | 硬编码 token / api-key / secret 字符串字面量 |
| `SEC-002` | High | hilog `%{public}` 输出 token / password / 身份证 |
| `SEC-007` | Medium | MD5 / SHA1 / DES 弱算法 |
| `CSPRNG-001` | High in security/, Medium otherwise | `Math.random()` 在加密上下文（含 PKCE verifier） |
| `CSPRNG-002` | High | `HUKS_TAG_IV` / `HUKS_TAG_NONCE` 同文件无 `cryptoFramework.createRandom`（GCM nonce / IV 似非 CSPRNG） |
| `ARKTS-DEPRECATED-PICKER` | High | `picker.PhotoViewPicker`（用 `photoAccessHelper`） |
| `ARKTS-DEPRECATED-DECODE` | High | `TextDecoder.decodeWithStream`（已弃用） |
| `KIT-001` | Medium | `http.createHttp()` 未 destroy |
| `KIT-003` | Medium | `@kit.ScanKit` 直接 import 真机不稳；改 dual-import `@hms.core.scan.*` |
| `KIT-004` | High | HMS ScanKit `ScanType.QRCODE` 已改名 `QR_CODE`，旧值 undefined |
| `DB-001` | High | `ResultSet` / `RdbStore` 未 close |

## 18. 相关文档

- `01-language-arkts/02-typescript-to-arkts-migration.md` — ArkTS 严格模式禁用项
- `03-platform-apis/` — Kit 系统能力索引
- `05-best-practices/` § 3 安全（同文件上方）
- `09-quick-reference/` — 装饰器 / 错误码速查
- `samples/templates/web-bridge-h5-shell/` — 最小 Web bridge 骨架
- `samples/templates/huks-secure-store/` — HUKS 硬件密钥保管示例
- `samples/templates/scan-qrcode/` — HMS ScanKit dual-import + page-bound ctx + 错误码处理（§11 配套）

---

> **来源**：本文 15 类陷阱沉淀自 2026-05 起一个真实下游消费者（企业级 AI 工作面 macOS / iPadOS / Android / HarmonyOS 四端套件）实战教训 + 评审反馈。具体出处可能因后续脱敏调整不再可追溯，但所有陷阱都在三端的至少一端实际遇到过、并被代码 review 拍板进规则。新增条目欢迎附最小复现路径。
