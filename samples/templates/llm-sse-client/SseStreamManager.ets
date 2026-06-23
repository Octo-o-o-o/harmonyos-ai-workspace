// SseStreamManager.ets
// 最小可用 SSE 流式客户端（OctoDesk Mobile 的简化版）
//
// 核心模式：
//   1. http.createHttp().requestInStream(url, options) 启动流
//   2. readTimeout = 0（LLM 慢思考不能被默认 30s 中断）
//   3. dataReceive 回调收 ArrayBuffer chunk → buffer 累积 → 按 \n\n 切帧
//   4. TextDecoder { stream: true } 保 UTF-8 多字节字符跨 chunk
//   5. cancel: stream.cancelled = true + request.destroy() + 删 Map entry
//   6. 三条结束路径（dataEnd / error / cancel）都走 cleanup
//   7. OpenAI-compatible streaming 若要 usage，显式加 stream_options.include_usage
//
// ArkTS V1 约束：
//   - 所有回调用箭头函数（arkts-no-func-expressions）
//   - 没有 any；BusinessError 显式 catch
//   - 类字段必须声明时或 constructor 内赋值

import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'

// ─── 业务接口 ─────────────────────────────────────────────────

export class SseStartRequest {
  endpoint: string = ''           // 相对路径，例如 '/v1/chat/completions'
  method: string = 'POST'         // 'GET' | 'POST'
  bodyJson: string | null = null  // POST 时必填，序列化后的 JSON
  bearer: string | null = null    // 可选 Bearer token
  lastEventId: string | null = null  // 断线续传可选
  // OpenAI Chat Completions / compatible endpoint：stream=true 时默认不会给 token usage。
  // 只有显式带 stream_options.include_usage=true，最后一个 usage chunk 才可能出现。
  // 注意：取消 / 网络中断时 final usage chunk 可能收不到；不支持该字段的 provider 应优雅降级。
  includeOpenAIUsage: boolean = false
}

export class OpenAIStreamOptions {
  include_usage: boolean = true
}

/**
 * 业务实现这个接口接收事件。一个 manager 可以服务多个 stream，
 * 每个事件带 streamId（= start() 的 correlationId）。
 */
export interface SseEventListener {
  onEvent(streamId: string, name: string, data: string): void
  onEnd(streamId: string, reason: string, errorCode: string | null): void
}

// ─── 内部状态 ─────────────────────────────────────────────────

class SseStream {
  request: http.HttpRequest
  decoder: util.TextDecoder
  buffer: string = ''
  cancelled: boolean = false

  constructor(req: http.HttpRequest) {
    this.request = req
    this.decoder = util.TextDecoder.create('utf-8')
  }
}

// ─── 主类 ─────────────────────────────────────────────────────

export class SseStreamManager {
  private baseUrl: string
  private streams: Map<string, SseStream> = new Map<string, SseStream>()

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl
  }

  async start(streamId: string, req: SseStartRequest, listener: SseEventListener): Promise<void> {
    if (this.streams.has(streamId)) {
      throw new Error(`SSE: stream ${streamId} already running`)
    }
    const method = req.method.toUpperCase()
    if (method !== 'GET' && method !== 'POST') {
      throw new Error('SSE: only GET / POST allowed')
    }
    if (method === 'POST' && (req.bodyJson === null || req.bodyJson.length === 0)) {
      throw new Error('SSE: POST requires bodyJson')
    }
    if (method === 'GET' && req.bodyJson !== null) {
      throw new Error('SSE: GET cannot include body')
    }

    const httpRequest = http.createHttp()
    const stream = new SseStream(httpRequest)
    this.streams.set(streamId, stream)

    // 构造 header（class 实例 → 字段赋值，避免 Record 字面量违反 ArkTS）
    const headers = new SseHeaders()
    headers.accept = 'text/event-stream'
    if (method === 'POST') {
      headers.contentType = 'application/json'
    }
    if (req.bearer !== null && req.bearer.length > 0) {
      headers.authorization = `Bearer ${req.bearer}`
    }
    if (req.lastEventId !== null && req.lastEventId.length > 0) {
      headers.lastEventId = req.lastEventId
    }

    const url = trimUrl(this.baseUrl, req.endpoint)
    const options: http.HttpRequestOptions = {
      method: method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
      header: headers.toRecord(),
      // 关键 1：readTimeout=0 让 LLM 慢思考不被中断
      readTimeout: 0,
      connectTimeout: 30_000,
      // 关键 2：拿原始 bytes 不让 SDK 自动解码 —— 我们要自己处理 SSE 帧
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
    }
    if (method === 'POST') {
      let body = req.bodyJson as string
      if (req.includeOpenAIUsage) {
        body = withOpenAIStreamUsage(body)
      }
      options.extraData = body
    }

    // 关键 3：全部用箭头函数（ArkTS 禁 function 表达式）
    httpRequest.on('dataReceive', (chunk: ArrayBuffer) => {
      this.consumeChunk(streamId, stream, chunk, listener)
    })
    httpRequest.on('dataEnd', () => {
      this.handleEnd(streamId, 'eof', null, listener)
    })
    httpRequest.on('headersReceive', (_h: Object) => {
      // No-op；第一帧 dataReceive 到来即代表流已开通
    })

    try {
      await httpRequest.requestInStream(url, options)
    } catch (e) {
      const err = e as BusinessError
      this.handleEnd(streamId, 'error', `code=${err.code}`, listener)
    }
  }

  cancel(streamId: string): void {
    const stream = this.streams.get(streamId)
    if (!stream) {
      return
    }
    stream.cancelled = true
    try {
      stream.request.destroy()
    } catch (_e) {
      // best effort —— 连接可能已自然结束
      // scan-ignore: ARKTS-016
    }
    this.streams.delete(streamId)
    // 主动通知 listener，业务可以同步 cleanup UI
    // 注意：cancel 后 dataEnd 不会再触发
  }

  cancelAll(): void {
    const ids: Array<string> = []
    this.streams.forEach((_v, k) => ids.push(k))
    for (let i = 0; i < ids.length; i++) {
      this.cancel(ids[i])
    }
  }

  // ─── chunk → frame 切分 ─────────────────────────────────────
  private consumeChunk(streamId: string, stream: SseStream, chunk: ArrayBuffer, listener: SseEventListener): void {
    if (stream.cancelled) {
      return
    }
    const bytes = new Uint8Array(chunk)
    // 关键：stream: true 让 UTF-8 多字节字符跨 chunk 时不乱码
    stream.buffer += stream.decoder.decodeToString(bytes, { stream: true })

    // SSE 帧分隔符 = \n\n
    let idx = stream.buffer.indexOf('\n\n')
    while (idx >= 0) {
      const frame = stream.buffer.substring(0, idx)
      stream.buffer = stream.buffer.substring(idx + 2)
      this.dispatchFrame(streamId, frame, listener)
      idx = stream.buffer.indexOf('\n\n')
    }
  }

  private dispatchFrame(streamId: string, frame: string, listener: SseEventListener): void {
    const parsed = parseSseFrame(frame)
    if (parsed === null) {
      return
    }
    listener.onEvent(streamId, parsed.name, parsed.data)
  }

  private handleEnd(streamId: string, reason: string, errorCode: string | null, listener: SseEventListener): void {
    if (!this.streams.has(streamId)) {
      return  // 已被 cancel 清理过
    }
    this.streams.delete(streamId)
    listener.onEnd(streamId, reason, errorCode)
  }
}

// ─── header 容器（避免 Record<string,string> 字面量） ─────────

class SseHeaders {
  accept: string = ''
  contentType: string | null = null
  authorization: string | null = null
  lastEventId: string | null = null

  toRecord(): Record<string, string> {
    const out: Record<string, string> = {}
    out['Accept'] = this.accept                          // scan-ignore: ARKTS-003
    if (this.contentType !== null) {
      out['Content-Type'] = this.contentType             // scan-ignore: ARKTS-003
    }
    if (this.authorization !== null) {
      out['Authorization'] = this.authorization          // scan-ignore: ARKTS-003
    }
    if (this.lastEventId !== null) {
      out['Last-Event-ID'] = this.lastEventId            // scan-ignore: ARKTS-003
    }
    return out
  }
}

function withOpenAIStreamUsage(bodyJson: string): string {
  const body = JSON.parse(bodyJson) as Record<string, Object>
  const streamOptions = new OpenAIStreamOptions()
  body['stream_options'] = streamOptions  // scan-ignore: ARKTS-003
  return JSON.stringify(body)
}

// ─── 单帧解析 ────────────────────────────────────────────────

class ParsedFrame {
  name: string = 'message'
  data: string = ''
  id: string = ''
}

function parseSseFrame(frame: string): ParsedFrame | null {
  const lines = frame.split('\n')
  const out = new ParsedFrame()
  let hasData: boolean = false

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    if (line.length === 0 || line.startsWith(':')) {
      continue
    }
    const colon = line.indexOf(':')
    const field = colon < 0 ? line : line.substring(0, colon)
    let value = colon < 0 ? '' : line.substring(colon + 1)
    if (value.startsWith(' ')) {
      value = value.substring(1)
    }
    if (field === 'data') {
      out.data = hasData ? out.data + '\n' + value : value
      hasData = true
    } else if (field === 'event') {
      out.name = value
    } else if (field === 'id') {
      out.id = value
    }
  }

  return hasData ? out : null
}

function trimUrl(base: string, path: string): string {
  let b = base
  if (b.endsWith('/')) {
    b = b.substring(0, b.length - 1)
  }
  const p = path.startsWith('/') ? path : '/' + path
  return b + p
}
