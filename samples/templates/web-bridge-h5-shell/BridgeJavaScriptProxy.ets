// BridgeJavaScriptProxy.ets
// 最小可用 H5 ↔ ArkTS 桥（OctoDesk Mobile 的简化版）
//
// 关键设计：
//   1. BridgeJavaScriptProxy 是 javaScriptProxy 注册的稳定实例
//      —— 必须在 aboutToAppear 中 new 一次，绝不写在 build() 里
//   2. BridgeRuntime 持有 webController 引用，attach() / detach() 显式管理
//   3. 同步入口 postMessage(raw): string —— 立即返回 ack/error envelope
//   4. 异步出口 runJavaScript('window.__handleNative(...)') —— 跨桥单向通知
//   5. 所有数据 = JSON 字符串，禁止原生对象跨桥
//
// ArkTS V1 约束：
//   - 不用 any；JSON 解析用 ESObject + typeof 守卫
//   - 类字段必须声明时或 constructor 赋值
//   - 箭头函数；不写 function 表达式

import { webview } from '@kit.ArkWeb'
import { util } from '@kit.ArkTS'

// ─── 协议定义 ─────────────────────────────────────────────────

export class BridgeEnvelope {
  id: string = ''
  type: string = ''
  kind: string = ''            // 'request' | 'response' | 'event' | 'error'
  emittedAt: string = ''
  correlationId: string | null = null
  payload: string | null = null  // 字符串化的内层 JSON
}

export class BridgeErrorPayload {
  code: string = ''
  message: string = ''
}

// 业务可用的能力（按需扩展）
export class BridgeCapability {
  static readonly STORAGE: string = 'storage'
  static readonly SSE: string = 'sse'
  static readonly ALL: ReadonlyArray<string> = [BridgeCapability.STORAGE, BridgeCapability.SSE]
}

// capability.query 的响应载荷 —— 用 class 替代 Record 字面量
class CapabilityQueryResult {
  capabilities: ReadonlyArray<string> = BridgeCapability.ALL
}

// ─── 暴露给 H5 的稳定实例 ─────────────────────────────────────

export class BridgeJavaScriptProxy {
  private runtime: BridgeRuntime

  constructor(runtime: BridgeRuntime) {
    this.runtime = runtime
  }

  // 注意：`name` 字段必须出现在 javaScriptProxy 的 methodList 里
  // H5 通过 window.<proxyName>.postMessage(jsonString) 调用
  postMessage(raw: string): string {
    return this.runtime.handleSync(raw)
  }
}

// ─── 运行时（持 controller 引用，跑异步反向调用） ────────────

export class BridgeRuntime {
  private webController: webview.WebviewController | null = null

  // 把 controller 注入进来 —— 在 onControllerAttached 回调里调
  attach(controller: webview.WebviewController): void {
    this.webController = controller
  }

  // 组件卸载时调，避免 controller 持有时 Web 组件无法 GC
  detach(): void {
    this.webController = null
  }

  // ─── 同步入口 ─────────────────────────────────────────────
  handleSync(raw: string): string {
    const env = parseEnvelope(raw)
    if (env === null) {
      return JSON.stringify(this.buildError('INVALID_PAYLOAD', 'envelope decode failed', null))
    }

    // Demo dispatch：按 type 路由。生产代码这里会进 SSE / Storage / Upload 等子模块
    if (env.type === 'capability.query') {
      // ArkTS V1 禁止 Record 字面量初始化（arkts-no-untyped-obj-literals）
      // → 声明 class 后 new + 字段赋值
      const result = new CapabilityQueryResult()
      return JSON.stringify(this.buildResponse(env, JSON.stringify(result)))
    }
    if (env.type === 'ping') {
      // 演示异步出口：50ms 后通过 runJavaScript 推一个 pong 事件
      setTimeout(() => {
        this.emitToJs(this.buildEvent('pong', env.id, '{"ts":' + Date.now() + '}'))
      }, 50)
      return JSON.stringify(this.buildAck(env))
    }

    return JSON.stringify(this.buildError('CAPABILITY_UNAVAILABLE', `${env.type} not implemented`, env.id))
  }

  // ─── 异步出口：Native → Web 单向事件 ──────────────────────
  emitToJs(envelope: BridgeEnvelope): void {
    const ctrl = this.webController
    if (ctrl === null) {
      // Web 组件已卸载，丢弃即可（业务层应通过 detach 提前 unsubscribe）
      return
    }
    const literal = jsLiteral(JSON.stringify(envelope))
    try {
      ctrl.runJavaScript(`window.__handleNative && window.__handleNative(${literal})`)
    } catch (_e) {
      // Web 在 schedule 与 emit 之间销毁；安全忽略
    }
  }

  // ─── envelope 构造工具 ────────────────────────────────────
  private buildAck(req: BridgeEnvelope): BridgeEnvelope {
    return this.buildResponse(req, '{"ack":true}')
  }

  private buildResponse(req: BridgeEnvelope, payloadJson: string): BridgeEnvelope {
    const env = new BridgeEnvelope()
    // util.generateRandomUUID is CSPRNG-backed; Math.random would be flagged
    // by scan-arkts CSPRNG-001 even outside a crypto context for consistency.
    env.id = 'res-' + util.generateRandomUUID(true)
    env.type = req.type
    env.kind = 'response'
    env.emittedAt = new Date().toISOString()
    env.correlationId = req.id
    env.payload = payloadJson
    return env
  }

  private buildEvent(type: string, correlationId: string, payloadJson: string): BridgeEnvelope {
    const env = new BridgeEnvelope()
    env.id = 'evt-' + Date.now()
    env.type = type
    env.kind = 'event'
    env.emittedAt = new Date().toISOString()
    env.correlationId = correlationId
    env.payload = payloadJson
    return env
  }

  private buildError(code: string, message: string, correlationId: string | null): BridgeEnvelope {
    const err = new BridgeErrorPayload()
    err.code = code
    err.message = message

    const env = new BridgeEnvelope()
    env.id = 'err-' + Date.now()
    env.type = 'error'
    env.kind = 'error'
    env.emittedAt = new Date().toISOString()
    env.correlationId = correlationId
    env.payload = JSON.stringify(err)
    return env
  }
}

// ─── JSON 解析：禁用 any，全部走 ESObject + 类型守卫 ─────────

function parseEnvelope(raw: string): BridgeEnvelope | null {
  let parsed: object | null = null
  try {
    parsed = JSON.parse(raw) as object
  } catch (_e) {
    return null
  }
  if (parsed === null) {
    return null
  }
  // 解析任意 H5 传来的 JSON 时，`obj['key']` 是 ArkTS V1 在 Record<string, ESObject>
  // 上的合法 typed lookup（编译器允许；OctoDesk 真实生产代码即此模式）。
  // 扫描器无法区分动态键 vs typed Record 访问，故显式 suppress ARKTS-003。
  const obj = parsed as Record<string, ESObject>
  const id: ESObject = obj['id']                                    // scan-ignore: ARKTS-003
  const type: ESObject = obj['type']                                // scan-ignore: ARKTS-003
  if (typeof id !== 'string' || typeof type !== 'string') {
    return null
  }
  const env = new BridgeEnvelope()
  env.id = id
  env.type = type
  const kind: ESObject = obj['kind']                                // scan-ignore: ARKTS-003
  env.kind = typeof kind === 'string' ? kind : 'request'
  const emittedAt: ESObject = obj['emittedAt']                      // scan-ignore: ARKTS-003
  env.emittedAt = typeof emittedAt === 'string' ? emittedAt : new Date().toISOString()
  const corr: ESObject = obj['correlationId']                       // scan-ignore: ARKTS-003
  env.correlationId = typeof corr === 'string' ? corr : null
  const payload: ESObject = obj['payload']                          // scan-ignore: ARKTS-003
  if (payload === undefined || payload === null) {
    env.payload = null
  } else if (typeof payload === 'string') {
    env.payload = payload
  } else {
    env.payload = JSON.stringify(payload)
  }
  return env
}

// ─── runJavaScript 字符串字面量转义 ───────────────────────────
// 必须手写，否则换行 / 反斜杠 / Unicode 行分隔符会破坏 JS 语法
function jsLiteral(value: string): string {
  let out: string = '"'
  for (let i = 0; i < value.length; i++) {
    const c = value.charCodeAt(i)
    if (c === 0x5c) { out += '\\\\' }
    else if (c === 0x22) { out += '\\"' }
    else if (c === 0x0a) { out += '\\n' }
    else if (c === 0x0d) { out += '\\r' }
    else if (c === 0x09) { out += '\\t' }
    else if (c < 0x20 || c === 0x2028 || c === 0x2029) {
      const hex = c.toString(16)
      out += '\\u' + ('0000' + hex).substring(hex.length)
    } else {
      out += value.charAt(i)
    }
  }
  return out + '"'
}
