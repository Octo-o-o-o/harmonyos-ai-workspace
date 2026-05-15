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

## 8. 反检查清单（上 PR 前过一遍）

- [ ] handshake 的 `granted` 来自 handler 注册表，不是 enum
- [ ] `BridgeCapability` enum 新增条目都有对应 handler，或者明确 reject + reason
- [ ] `javaScriptProxy` 在 `aboutToAppear()` 之前完成 attach、proxy 实例不在 `build()` 内 new
- [ ] mutating message 都在 `BRIDGE_MUTATING_TYPES` 白名单内、入口拒绝缺 `idempotencyKey`
- [ ] envelope 走过 `validateBridgeEnvelope`，未通过的 reject 不 dispatch
- [ ] hilog dump / 错误回执的字段过滤过 token / password / refreshToken
- [ ] picker URI 不进任何缓存 / 后台 task；要后续读改走 Folder Import
- [ ] 加密路径全 `cryptoFramework`，scanner 的 `CSPRNG-001` exit 0
- [ ] `addJavascriptInterface` / 已废弃 `picker.PhotoViewPicker` / `decodeWithStream` 全 0 命中（scanner 覆盖：`ARKTS-DEPRECATED-PICKER` / `ARKTS-DEPRECATED-DECODE`）

## 9. 相关 scan-arkts 规则

| 规则 ID | 严重度 | 覆盖什么 |
|--------|--------|---------|
| `SEC-001` | High | 硬编码 token / api-key / secret 字符串字面量 |
| `SEC-002` | High | hilog `%{public}` 输出 token / password / 身份证 |
| `SEC-007` | Medium | MD5 / SHA1 / DES 弱算法 |
| `CSPRNG-001` | High in security/, Medium otherwise | `Math.random()` 在加密上下文 |
| `CSPRNG-002` | High | `HUKS_TAG_IV` 同文件无 `cryptoFramework.createRandom`（IV 似非 CSPRNG） |
| `ARKTS-DEPRECATED-PICKER` | High | `picker.PhotoViewPicker`（用 `photoAccessHelper`） |
| `ARKTS-DEPRECATED-DECODE` | High | `TextDecoder.decodeWithStream`（已弃用） |
| `KIT-001` | Medium | `http.createHttp()` 未 destroy |
| `DB-001` | High | `ResultSet` / `RdbStore` 未 close |

## 10. 相关文档

- `01-language-arkts/02-typescript-to-arkts-migration.md` — ArkTS 严格模式禁用项
- `03-platform-apis/` — Kit 系统能力索引
- `05-best-practices/` § 3 安全（同文件上方）
- `09-quick-reference/` — 装饰器 / 错误码速查
- `samples/templates/web-bridge-h5-shell/` — 最小 Web bridge 骨架
- `samples/templates/huks-secure-store/` — HUKS 硬件密钥保管示例

---

> **来源**：本文 8 类陷阱沉淀自 2026-05 一个真实下游消费者（企业级 AI 工作面 macOS / iPadOS / Android / HarmonyOS 四端套件）实战教训 + 评审反馈。具体出处可能因后续脱敏调整不再可追溯，但所有陷阱都在三端的至少一端实际遇到过、并被代码 review 拍板进规则。新增条目欢迎附最小复现路径。
