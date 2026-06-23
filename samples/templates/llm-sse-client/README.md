# Recipe · LLM SSE 流式客户端（最小可用）

> ArkTS V1 调 OpenAI / Claude / Gemini / 自建 LLM 服务的 SSE 流式接口的骨架。
>
> **真实出处**：OctoDesk Mobile 的 `SseStreamManager.ets` 简化版。已剥去鉴权 token provider / endpoint 白名单等业务，保留与 SSE 协议本身相关的稳定模式。
>
> verified_against: harmonyos-6.0.2-api22

## 什么时候用

- 调任何返回 `text/event-stream` 的 LLM 接口（OpenAI Chat Completions stream / Claude Messages stream / 自建网关）
- 需要在用户取消时立即中断流（不等服务端响应）
- 跨平台一致：iOS / Android / 鸿蒙都要类似的流式管理

## 什么时候**不要**用

- 服务端是 WebSocket → 用 `@ohos.net.webSocket`
- 一次性返回的请求 → 直接 `http.request()`，别用 stream
- 流式时间总长 < 500ms → 通常不值得增加 SSE 复杂度

## 约束（必须满足）

1. **`requestInStream` 的 `readTimeout` 必须设为 0**，否则一段时间没数据会主动断流（LLM 思考阶段就翻车）。`connectTimeout` 留 30s 即可。
2. **半包 buffer 必须按 `\n\n` 切帧**——chunk 边界不等于 SSE 帧边界，OpenAI 一个 chunk 可能含 0~10 个事件。
3. **`TextDecoder.decodeToString(bytes, { stream: true })`** 必须带 `stream: true`，否则 UTF-8 多字节字符跨 chunk 时会乱码。
4. **取消时必须 `request.destroy()` + 从 streams Map 删除**，否则下次启动同 correlationId 会撞"已在运行"。
5. **`dataEnd` / `dataReceive` / 异常**三条路径都必须 cleanup，不能假设一定走 `dataEnd`——HTTP 500 / 网络断开 / 服务端 abort 都不会进 dataEnd。
6. **绝不写 `function() { ... }` 表达式**，回调统一用箭头函数（ArkTS 限制）。
7. **OpenAI-compatible streaming 要 token usage 必须显式请求**：`stream: true` 默认只给 delta，不保证 usage。请求体加 `stream_options.include_usage=true` 后，最后一个 chunk 才可能包含 usage；cancel / 网络中断时最后一帧可能收不到。

## 集成步骤

1. 把 `SseStreamManager.ets` 复制到 `entry/src/main/ets/sse/`
2. 加权限（`module.json5`）：

```json5
{ "module": { "requestPermissions": [ { "name": "ohos.permission.INTERNET" } ] } }
```

3. 在你的业务层使用：

```typescript
import { SseStreamManager, SseEventListener } from './sse/SseStreamManager'

class ChatViewModel implements SseEventListener {
  private mgr: SseStreamManager = new SseStreamManager('https://api.example.com')

  async start() {
    await this.mgr.start('chat-1', {
      endpoint: '/v1/chat/completions',
      method: 'POST',
      bodyJson: JSON.stringify({ model: 'gpt-4', stream: true, messages: [...] }),
      bearer: 'sk-...',
      includeOpenAIUsage: true,
    }, this)
  }

  onEvent(streamId: string, name: string, data: string): void {
    // data 是单帧 SSE 的 data: 段（OpenAI 把 JSON delta 塞这里）
    // 若 includeOpenAIUsage=true，最后一帧可能是 choices=[] + usage={...}
    // 不要无条件读 choices[0]；usage 缺失时按"未知"处理。
  }

  onEnd(streamId: string, reason: string, errorCode: string | null): void {
    // reason: 'eof' / 'cancelled' / 'error'
  }
}

// 用户点取消按钮
this.mgr.cancel('chat-1')
```

## 验证

```bash
bash tools/hooks/lib/scan-arkts.sh SseStreamManager.ets
# 期望：无 STATE-002 / ARKTS-016（空 catch）/ SEC-* 命中

hvigorw codeLinter
# 期望：无 arkts-no-* 报错
```

## 反模式（AI 常踩）

- ❌ 用 `http.request()`（同步）调 SSE 端点——会把整个流读到内存
- ❌ `readTimeout` 不设 0 用默认值（30s）——LLM 慢思考会被中断
- ❌ 在 `dataReceive` 里直接 `JSON.parse(new TextDecoder().decode(chunk))`——chunk 边界不等于帧边界，60% 概率失败
- ❌ 取消时只删 Map 不调 `destroy()`——HTTP 连接泄漏
- ❌ 用 `function() { ... }` 写 `dataReceive` 回调——ArkTS 编译报 `arkts-no-func-expressions`
- ❌ 以为 `stream: true` 会自动返回 usage——OpenAI-compatible 端点需显式 `stream_options.include_usage=true`
- ❌ 解析 OpenAI chunk 时无条件读 `choices[0]`——usage 末帧可能 `choices=[]`

## 扩展点

OctoDesk 真实工程在此骨架上加了：

- **endpoint 白名单**：`isAllowed()` 用 regex 数组检查（防 H5 桥传任意 URL）
- **Last-Event-ID / Resume Token** 断线续传 header
- **bearer token 走 Promise provider**（每次 start 时拿最新 access token）
- **回调改成 BridgeForwarder 接口**：转成 H5 桥事件转发给 WebView
- **usage 末帧转 exec-meta**：只在 final chunk 确实带 usage 时写；无 usage / 被取消 / provider 忽略字段时不报错

按需扩展即可。
