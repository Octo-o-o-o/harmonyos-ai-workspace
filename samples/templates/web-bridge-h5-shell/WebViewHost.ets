// WebViewHost.ets
// 最小可用 ArkUI Web 容器（OctoDesk Mobile 的简化版）
//
// 关键设计：
//   1. `runtime` 与 `proxy` 都在 aboutToAppear 创建一次 —— 关键！
//      不能写在 build() 里或者 javaScriptProxy({ object: new Proxy() })
//      否则每次重渲染都重新注册 proxy，window.<name>.postMessage 会失效
//   2. onControllerAttached 是把 controller 注入 runtime 的唯一时机
//   3. onLoadIntercept 做域名白名单 —— 上架审核 AGC-RJ-007 要求
//   4. aboutToDisappear 调 runtime.detach() 释放 controller 引用

import { webview } from '@kit.ArkWeb'

import { BridgeJavaScriptProxy, BridgeRuntime } from './BridgeJavaScriptProxy'

// 上架审核会查域名白名单，所以只放确实需要的
const ALLOWED_HOSTS: ReadonlyArray<string> = [
  'api.example.com',
]

@Component
export struct WebViewHost {
  // 这些必须是组件级稳定字段，不能写在 build() 里 ──────────
  private webController: webview.WebviewController = new webview.WebviewController()
  private runtime: BridgeRuntime = new BridgeRuntime()
  private proxy: BridgeJavaScriptProxy = new BridgeJavaScriptProxy(this.runtime)

  aboutToAppear(): void {
    try {
      // 生产环境必须 false；调试时改 true，开 DevTools 检查 H5
      webview.WebviewController.setWebDebuggingAccess(false)
    } catch (_e) {
      // best effort
    }
  }

  aboutToDisappear(): void {
    this.runtime.detach()
  }

  build(): void {
    Web({
      // 你的 H5 离线包入口；放在 entry/src/main/resources/rawfile/dist/ 下
      src: 'resource://rawfile/dist/index.html',
      controller: this.webController,
    })
      // 安全设置 —— 默认收紧
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .fileAccess(false)
      .imageAccess(true)
      .mixedMode(MixedMode.None)
      .multiWindowAccess(false)
      // 关键：proxy 是上面声明的稳定实例 ─────────────────────
      .javaScriptProxy({
        object: this.proxy,
        // H5 通过 window.<name>.postMessage(json) 调用
        name: 'appBridge',
        // 暴露的方法白名单 —— 只允许这一个
        methodList: ['postMessage'],
        controller: this.webController,
      })
      // 关键：在这里把 controller 注入 runtime，之后 runJavaScript 才有效
      .onControllerAttached(() => {
        this.runtime.attach(this.webController)
      })
      // 域名白名单：除 rawfile 外，只允许白名单内的 host
      .onLoadIntercept((event) => {
        const url = event.data.getRequestUrl()
        if (url.startsWith('resource://')) {
          return false
        }
        for (let i = 0; i < ALLOWED_HOSTS.length; i++) {
          if (url.indexOf('://' + ALLOWED_HOSTS[i]) >= 0) {
            return false
          }
        }
        // 拦截 —— 不允许外链
        return true
      })
  }
}
