---
name: web-bridge
verified_against: harmonyos-6.0.2-api22  # last sync 2026-05-07
description: |
  ArkUI Web 组件 + H5 ↔ ArkTS 双向桥（javaScriptProxy / runJavaScript / postMessage）的领域专项。
  **激活条件**（满足任一即激活）：
    - 用户写"ArkUI Web 组件 / 嵌入 H5 / WebView"
    - 代码出现 `Web({ src: ... })`、`webview.WebviewController`、`javaScriptProxy`、`runJavaScript`
    - 涉及把 markdown / HTML / 富文本渲染到鸿蒙 app（用 H5 离线渲染器代替原生）
    - H5 调用 ArkTS（如 `window.reporter.log(...)`）或反向调用
  **不激活**：纯 ArkUI 原生组件渲染；Web 浏览器 app（用 Web Browser Kit 而非 ArkUI Web）。
---

# ArkUI Web 组件 · H5↔ArkTS 桥专项

> 鸿蒙 ArkUI 的 `Web` 组件常用于 markdown 渲染 / 复杂富文本 / 第三方 H5 嵌入。这一类场景**不像 React Native 的 WebView 那么直白**——有几个特定坑只在鸿蒙体现。

## 一、`javaScriptProxy` 的稳定实例约束

### 现象
H5 调用 `window.reporter.log(...)` 偶发失败，或第二次进入页面后失效。

### 原因
`Web().javaScriptProxy({ object: ... })` 的对象引用必须**整个组件生命周期内稳定**。在 `build()` 内 inline `{ object: { fn: () => {...} } }` → 每次重渲染重建对象 → 桥丢失。

### 正确写法

```typescript
import { webview } from '@kit.ArkWeb';

// ⚠️ proxy class 单独声明，不能用字面量
class ReporterProxy {
  log(level: string, msg: string): void {
    hilog.info(0xBEEF, 'h5', '[%{public}s] %{public}s', level, msg);
  }

  // H5 想异步获取数据：用 Promise + 双方约定 callback
  async getUserSetting(key: string): Promise<string> {
    // ... 读 Preferences
    return 'value';
  }
}

@Component
export struct WebContainer {
  @State htmlSrc: string = 'resource://rawfile/markdown-renderer.html';
  controller: webview.WebviewController = new webview.WebviewController();
  // ⚠️ 单实例，aboutToAppear 建一次
  private reporter: ReporterProxy | null = null;

  aboutToAppear(): void {
    this.reporter = new ReporterProxy();
  }

  aboutToDisappear(): void {
    // 解绑桥（防内存泄漏）
    this.controller.deleteJavaScriptRegister('reporter');
  }

  build() {
    Web({ src: this.htmlSrc, controller: this.controller })
      .javaScriptAccess(true)
      .javaScriptProxy({
        object: this.reporter!,           // ✅ 引用稳定
        name: 'reporter',
        methodList: ['log', 'getUserSetting'],
        controller: this.controller,
      })
      .onPageEnd(() => {
        // 页面加载完后再注入业务初始数据（避免 race）
        this.controller.runJavaScript("window.app?.init('data')");
      })
  }
}
```

### 反模式

```typescript
// ❌ 字面量每次 build 重建
.javaScriptProxy({
  object: { log: (msg: string) => { /* ... */ } },  // ← 每次新建
  name: 'reporter',
  methodList: ['log'],
})
```

## 二、ArkTS → H5 调用：runJavaScript 时序

### 现象
`controller.runJavaScript('window.app.init(...)')` 在 H5 还没加载完时调用 → undefined 错误。

### 正确模式

```typescript
// 监听 onPageEnd（H5 已 DOMContentLoaded）后再调
.onPageEnd(() => {
  this.controller.runJavaScript("window.app?.init('initial-data')");
})

// 或者 H5 主动通知就绪：
// H5: window.reporter.log('ready', '');  // 触发 ArkTS 端 onReady
```

## 三、Markdown 离线渲染器 · 标准模式

鸿蒙没有原生 markdown 组件。标配做法：

1. `entry/src/main/resources/rawfile/markdown-renderer.html` —— 离线 HTML，含 `<script src="markdown-it.min.js"></script>`
2. ArkTS 把原文通过 `javaScriptProxy` 暴露的 setter 推给 H5
3. H5 渲染后，用 `ResizeObserver` 监听内容高度，回调 ArkTS 调整 Web 组件高度

### `ResizeObserver` 高度自适应

```javascript
// markdown-renderer.html 内
const ro = new ResizeObserver(entries => {
  for (const e of entries) {
    const h = e.contentRect.height;
    window.reporter?.notifyHeight(Math.ceil(h));
  }
});
ro.observe(document.body);
```

```typescript
// ArkTS 端
class ReporterProxy {
  // ... 其他方法
  notifyHeight(h: number): void {
    AppStorage.set('webHeight', h);   // 触发组件 build
  }
}

@Component
struct MarkdownView {
  @StorageLink('webHeight') webH: number = 200;

  build() {
    Web({ ... })
      .height(this.webH)
      // ...
  }
}
```

### 关键资源

- markdown-it（轻量 MD parser）走离线 bundle
- 不要用 CDN（用户离线时白屏）
- bundle 体积 < 200 KB（`AGC-RJ-015` 包大小红线）

## 四、Web 组件常被忽略的安全设置

```typescript
Web({ src, controller: this.controller })
  .javaScriptAccess(true)              // 必须开（除非纯静态）
  .domStorageAccess(true)               // 启用 localStorage
  .fileAccess(false)                    // 安全：禁 file:// 访问
  .imageAccess(true)
  .mixedMode(MixedMode.None)            // 安全：禁 HTTP 混合（HTTPS 页面不允许加 HTTP 资源）
  .geolocationAccess(false)             // 不需要就关（隐私 + AGC 拒因）
  .onSslErrorEventReceive((err) => {
    // 默认拦截非法 cert，AGC 提审会查
    err.handler.handleCancel();
  })
```

**关联拒因**：[`AGC-RJ-001`](../../../07-publishing/checklist-2026-rejection-top20.md)（隐私）+ AGC 安全审核要求 https-only。

## 五、性能注意

- Web 组件初始化重：避免在长列表的 ListItem 里嵌 Web。改用"点击展开"
- 同时多个 Web 组件 → 内存暴涨。如要多个 markdown 渲染器，**复用 1 个 Web + 切换内容**
- 长内容用 `runJavaScript` 推 → 改成 `javaScriptProxy` 的 getter 让 H5 主动拉

## 六、调试

```bash
# 让 Web 组件支持 chrome://inspect 远程调试
hdc fport tcp:9222 tcp:9222
# Chrome 打开 chrome://inspect/#devices
```

ArkTS 端开关：

```typescript
webview.WebviewController.setWebDebuggingAccess(true);   // 仅 debug build 开
```

## 反模式总览

```typescript
// ❌ 1. javaScriptProxy 字面量（每次 build 重建）—— 见上
// ❌ 2. onPageBegin 调 runJavaScript（H5 还没加载完）
// ❌ 3. Web 组件嵌在 ForEach 里多个实例
// ❌ 4. 不解绑：aboutToDisappear 没 deleteJavaScriptRegister 导致内存泄漏
// ❌ 5. 用 file:// 协议 / 信任所有 cert（AGC 拒）
// ❌ 6. CDN 拉 markdown-it.js（用户离线白屏）
```

## 进一步参考

- 工程层装配陷阱：[`runtime-pitfalls`](../runtime-pitfalls/SKILL.md) § 五
- 多模态 LLM（常一起用）：[`multimodal-llm`](../multimodal-llm/SKILL.md)
- 官方 Web 组件文档：`upstream-docs/.../reference/apis-arkweb/`
