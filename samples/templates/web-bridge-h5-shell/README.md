# Recipe · ArkUI Web 组件 H5 桥（最小可用）

> H5 容器型企业 app 的核心骨架：ArkUI `Web` 组件加载本地 React/Vue 离线包，通过 `javaScriptProxy` 双向桥与 ArkTS 通信。
>
> **真实出处**：OctoDesk Mobile（4.3K 行生产工程）的 `BridgeJavaScriptProxy.ets` + `WebViewHost.ets` 简化版。已剥去鉴权 / 上传 / MDM / 推送等业务，保留**与桥本身相关的稳定模式**。
>
> verified_against: harmonyos-6.0.2-api22

## 什么时候用

- 你有现成的 H5 / React / Vue SPA，希望以最小成本壳化到鸿蒙
- 业务复杂度高，鸿蒙端只做**原生能力适配**（SSE、HUKS、推送、文件选择）
- 跨平台（iOS / Android / 鸿蒙）共享一套前端代码

## 什么时候**不要**用

- 纯展示型轻量 app —— 直接用 ArkUI 写
- 对启动速度 / 包大小敏感 —— H5 容器冷启动 2x 慢于原生
- 需要复杂滚动动效、手势协同 —— ArkUI Web 组件的滚动事件与外层 ArkUI 容器协同有局限

## 约束（必须满足）

1. **`javaScriptProxy` 的 object 必须是组件级稳定实例** —— 不能 `object: new BridgeProxy(...)` 写在 `build()` 里。每次重渲染 new 一个，proxy 会注册失败、`window.octodeskBridge.postMessage` 会变 undefined。本 recipe 用 `aboutToAppear` 一次性创建。
2. **`runJavaScript` 必须在 `onControllerAttached` 之后才能调用**。在 `aboutToAppear` 里调会拿到 null controller。本 recipe 用 `attach()` / `detach()` 显式管理 controller 生命周期。
3. **跨桥只传 JSON 字符串**，不传原生对象。`postMessage(raw: string): string` 是同步入口，异步结果走 `runJavaScript('window.__handleNative(...)')`。
4. **不能用 `any`** —— 解析 JSON envelope 必须用 `ESObject` + `typeof` 守卫。本 recipe 含可粘贴的 `parseEnvelope` 模板。
5. **域名白名单** —— `onLoadIntercept` 拦截外链。生产 app 通常只允许 `resource://` + 1-2 个可信域名。

## 集成步骤

1. 把 `BridgeJavaScriptProxy.ets` 和 `WebViewHost.ets` 复制到 `entry/src/main/ets/bridge/` 与 `entry/src/main/ets/webview/`
2. 在 `module.json5` 加权限：

```json5
{
  "module": {
    "requestPermissions": [
      { "name": "ohos.permission.INTERNET" }
    ]
  }
}
```

3. 把你的 H5 离线包放到 `entry/src/main/resources/rawfile/dist/`（含 `index.html`）
4. 在某个页面里挂载 `WebViewHost`：

```typescript
@Entry
@Component
struct Index {
  build() {
    Column() {
      WebViewHost()
    }
  }
}
```

5. H5 侧 JS 通过全局对象通信：

```javascript
// 发送（同步返回）
const responseJson = window.appBridge.postMessage(JSON.stringify({
  id: 'msg-' + Date.now(),
  type: 'storage.get',
  payload: { key: 'theme' }
}));

// 接收异步事件
window.__handleNative = (envelopeJson) => {
  const env = JSON.parse(envelopeJson);
  // ... 处理 sse.event / sse.end / push.received 等
};
```

## 验证

```bash
bash tools/hooks/lib/scan-arkts.sh BridgeJavaScriptProxy.ets WebViewHost.ets
# 期望：无 STATE-002 / ARKTS-001 / SEC-* 命中

hvigorw codeLinter
# 期望：无 arkts-no-* 报错
```

## 扩展点

OctoDesk 真实工程在此骨架上加了：

- **鉴权事件**：Native → Web 的 `auth.token.set` / `auth.token.clear` 单向事件（refresh token 留在原生侧）
- **SSE 集成**：`sse.start` / `sse.cancel` 委托给 [`llm-sse-client/`](../llm-sse-client/) 配套 recipe
- **安全存储**：`storage.get/set/wipe` 委托给 [`huks-secure-store/`](../huks-secure-store/) 配套 recipe
- **deeplink 路由** / **MDM 配置** / **窗口布局变化** 单向 Native→Web 事件

需要这些扩展时按 OctoDesk 源码（开源后）参考。

## 反模式（AI 常踩）

- ❌ `javaScriptProxy({ object: new Proxy(...) })` 写在 `.javaScriptProxy(...)` 调用里——重渲染失效
- ❌ 在 `aboutToAppear` 里调 `controller.runJavaScript()`——controller 还未 attach
- ❌ 用 `as any` 跳过 envelope 类型校验——ArkTS V1 严格类型 + 容易引入未测路径
- ❌ 不做域名白名单，直接信任 `event.data.getRequestUrl()`——上架审核 `AGC-RJ-007` 拒因
