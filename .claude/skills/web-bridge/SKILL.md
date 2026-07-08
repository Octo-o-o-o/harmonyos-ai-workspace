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

## 三、移动 WebView 软键盘 / visualViewport

### 现象

手机形态里聊天输入框或底部工具条用 `position: sticky` / `100vh`，在 ArkWeb / Android
WebView / WKWebView 里一弹软键盘就被遮住，或者底部 tabbar 与输入框重叠。只看桌面浏览器
devtools 复现不了，因为移动 WebView 有 layout viewport 与 visual viewport 两套高度。

### 正确模式

Web 侧统一维护 keyboard inset：监听 `window.visualViewport.resize/scroll`、`focusin/focusout`
和 `resize`，把结果写到根容器 CSS 变量，布局只消费这个变量。不要让每个组件自己猜键盘高度。

```javascript
let closedHeight = Math.max(window.innerHeight, document.documentElement.clientHeight);

function updateKeyboardInset() {
  const vv = window.visualViewport;
  const layoutHeight = Math.max(window.innerHeight, document.documentElement.clientHeight);
  const visualBottom = vv ? vv.offsetTop + vv.height : layoutHeight;
  const active = document.activeElement;
  const editing = active instanceof HTMLInputElement || active instanceof HTMLTextAreaElement;
  if (!editing) closedHeight = Math.max(closedHeight, layoutHeight, vv ? vv.height : 0);
  const inset = editing ? Math.max(0, closedHeight - visualBottom, layoutHeight - visualBottom) : 0;
  document.documentElement.style.setProperty('--keyboard-inset', `${Math.round(inset)}px`);
}

window.visualViewport?.addEventListener('resize', updateKeyboardInset);
window.visualViewport?.addEventListener('scroll', updateKeyboardInset);
document.addEventListener('focusin', updateKeyboardInset);
document.addEventListener('focusout', () => window.setTimeout(updateKeyboardInset, 80));
```

CSS 侧：

```css
.composer {
  position: fixed;
  bottom: calc(env(safe-area-inset-bottom) + var(--keyboard-inset, 0px));
}
```

### 要点

- 需要 2-3 次 settle timer（如 80ms / 220ms）处理键盘动画期间 viewport 分多次变化。
- 横竖屏 / 折叠态宽度变化时刷新 closed baseline，否则会把旋转误判成键盘。
- 键盘打开时隐藏或上移底部 tabbar，避免两个 fixed dock 抢同一条底边。
- ArkWeb 没有可靠的 JS API 直接读系统键盘高度；visualViewport 是最小跨端合同。

## 四、Picker 上传 / RAG 验收边界

WebView companion 如果通过 native picker 选择文件，再上传到服务端做 Chat/RAG，验收要拆成三道门：

1. **系统 picker 可见 fixture**：`hdc file send` 到 `/data/local/tmp` 或应用沙盒，不等于 picker 能选到。文本 fixture 需要通过 Files / Gallery / 系统分享导入，或由用户手动放到 picker 可见位置。
2. **上传 + ingest readback**：UI 显示"上传完成"只是第一层；还要看服务端 file record、ingest 状态和失败重试记录。
3. **内容答案**：用 `.md` / `.txt` / PDF 中的唯一哨兵句提问，回答命中内容事实才算内容级 RAG。只回答文件名、MIME、大小，属于 metadata-bound smoke，不能替代内容 RAG。

边界：picker URI 仍是 one-shot，不缓存、不后台轮询、不把本地路径交给 page world。图片 flow 如走视觉模型，单独标成 vision smoke。

## 五、Markdown 离线渲染器 · 标准模式

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

## 六、Web 组件常被忽略的安全设置

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

## 七、性能注意

- Web 组件初始化重：避免在长列表的 ListItem 里嵌 Web。改用"点击展开"
- 同时多个 Web 组件 → 内存暴涨。如要多个 markdown 渲染器，**复用 1 个 Web + 切换内容**
- 长内容用 `runJavaScript` 推 → 改成 `javaScriptProxy` 的 getter 让 H5 主动拉

## 八、调试

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
// ❌ 7. 把 metadata-bound 文件名回答当成内容级 RAG 通过
```

## 进一步参考

- 工程层装配陷阱：[`runtime-pitfalls`](../runtime-pitfalls/SKILL.md) § 五
- 多模态 LLM（常一起用）：[`multimodal-llm`](../multimodal-llm/SKILL.md)
- 官方 Web 组件文档：`upstream-docs/.../reference/apis-arkweb/`
