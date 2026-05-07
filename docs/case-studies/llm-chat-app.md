# Case Study · LLM 对话客户端工程笔记

> **来源声明**：本笔记基于一个真鸿蒙 LLM 对话 app（化名 LCC = LLM Chat Client）M3-M12 多个里程碑的反馈整理。**为可读性做了范型化处理**——具体里程碑章节的错误信息、修复 diff 是从真用户反馈中提炼的代表性案例，**不一定 1:1 对应该 app 的真实代码**。
>
> 个别章节（如 M9 BackupManager）讨论的是"工程上常见的此类问题"而非"该 app 真踩到了"。读者请把每节当作"领域里典型的一类问题 + 关联规则 + 修复方向"，而非考古实录。
>
> 每节结构：**症状 → 错误信息原文 → 修复 diff → 一句话教训**。比抽象规则更有说服力。
>
> 关联 SKILLS：[`runtime-pitfalls`](../../.claude/skills/runtime-pitfalls/SKILL.md) / [`multimodal-llm`](../../.claude/skills/multimodal-llm/SKILL.md) / [`web-bridge`](../../.claude/skills/web-bridge/SKILL.md) / [`arkts-rules`](../../.claude/skills/arkts-rules/SKILL.md) / [`state-management`](../../.claude/skills/state-management/SKILL.md)

---

## 工程背景

LCC 是一个支持 OpenAI / Anthropic / Gemini 多模型、多模态（Vision / Whisper / DALL-E）、流式输出 + Markdown 渲染的鸿蒙 app。多模块架构：

```
LCC/
├── common/              # 通用基础（Tokens / I18n / PrefStore / SecurityHelper）
├── chat/                # 对话核心（ChatStore / LlmClient / 流式渲染）
├── conversation/        # 会话列表
├── settings/            # 设置（AppShell / 6 组导航）
└── entry/               # 入口
```

实际经历的里程碑 M3-M12 涉及：状态管理、多模态 LLM、Web 组件桥、HUKS 加密、模块改名、主题切换、多端适配、上架准备。

---

## M3 · ChatStore 加方法 → STATE-002 救命

### 症状
最初实现 `ChatStore.addMessage(msg)` 时直接 `this.messages.push(msg)`，UI 没刷新。

### 修复 diff

```diff
 class ChatStore {
   @Trace messages: ChatMessage[] = [];

   addMessage(msg: ChatMessage): void {
-    this.messages.push(msg);
+    this.messages = [...this.messages, msg];
   }

   appendToLastMessage(delta: string): void {
-    const last = this.messages[this.messages.length - 1];
-    last.contentText += delta;
+    const last = this.messages[this.messages.length - 1];
+    const updated = { ...last } as ChatMessage;
+    updated.contentText = last.contentText + delta;
+    this.messages = [...this.messages.slice(0, -1), updated];
   }
 }
```

### 教训
**任何 `@State` / `@Local` / `@Trace` 字段的变更都必须替换引用**——这是 ArkEval 数据 42% LLM 错误的来源（`STATE-002`）。流式追加 token 这种"看起来只是改最后一项"的场景最容易踩。

---

## M4 · V1 vs V2 决策 · 一致性优先

### 症状
新写 `AssistantStore` 时纠结：用 V1（与 ChatStore 一致）还是 V2（写新代码用更严格的）？

### 决策
**沿用 V1**。理由：

1. ChatStore 是 V1（@Observed + @ObjectLink），跨 store 引用时 V1↔V2 互操作有摩擦
2. AssistantStore 用到的特性（@State / @Watch）V1 都有
3. **一致性 > 局部优化**

### 教训
v1/V2 选型不是"看哪个新"，是"看跟既有代码一致性"。同一文件 / 跨 store 不混用（`STATE-001`）。

---

## M5 · 多模态 Vision payload · ArkTS 拒 union

### 症状
按 OpenAI 文档实现 `ChatMessage`：

```typescript
interface ChatMessage {
  role: 'user' | 'assistant' | 'system';
  content: string | ContentPart[];   // ❌
}
```

`hvigorw codeLinter` 报：

```
arkts-no-union-types: ArkTS does not support union types in this context
```

### 修复 diff

```diff
 class ChatMessage {
   role: string = 'user';
-  content: string | ContentPart[] = '';
+  // 互斥：纯文本时 contentText；多模态时 contentParts
+  contentText: string = '';
+  contentParts: ContentPart[] = [];
+
+  toApiPayload(): object {
+    if (this.contentParts.length > 0) {
+      return { role: this.role, content: this.contentParts.map(p => p.toApiPart()) };
+    }
+    return { role: this.role, content: this.contentText };
+  }
 }
```

### 教训
ArkTS 严格类型 = **没有 union**。任何 TypeScript / Python LLM SDK 抄来的 `string | object` 都得拆双字段 + 自定义序列化。**完整模式**见 [`multimodal-llm`](../../.claude/skills/multimodal-llm/SKILL.md)。

---

## M6 · 流式 SSE 解析 · decodeWithStream 弃用

### 症状

```typescript
const dec = util.TextDecoder.create('utf-8');
const text = dec.decodeWithStream(buffer);   // ⚠️ deprecated warning
```

### 修复 diff

```diff
-const text = dec.decodeWithStream(buffer);
+const text = dec.decodeToString(buffer, { stream: true });
```

### 教训
HarmonyOS 6 起多个 API 改名（`decodeWithStream` / `picker.PhotoViewPicker` / `Configuration` 等）。**AI 训练数据停留在 API 9-11，会写出 deprecated**。本仓库 `tools/hooks/lib/scan-arkts.sh` 加了 `ARKTS-DEPRECATED-DECODE` / `ARKTS-DEPRECATED-PICKER` 等规则自动检测。

---

## M7 · Tokens 主题切换 · 改了不重渲染

### 症状
SettingsPage 切换 dark / light，AppStorage 里 `appearanceTheme` 已经更新，但 ChatPage 颜色没变。

### 排查
1. `colorTextPrimary()` 是函数式 token —— ✅
2. ChatPage build() 用 `Text(...).fontColor(colorTextPrimary())` —— ✅
3. ChatPage 没订阅 `appearanceTheme` → AppStorage 字段变化不触发它 build() —— ❌

### 修复 diff

```diff
 @Entry @Component
 struct ChatPage {
+  @StorageLink('appearanceTheme') theme: string = 'light';
+
   build() {
     Text(...).fontColor(colorTextPrimary())
   }
 }
```

### 教训
鸿蒙的"主题切换"= **函数式 token + 组件订阅 `@StorageLink('appearanceTheme')` 双条件成立才能触发重渲染**。任何"颜色随主题变"的页面都必须订阅这个字段。详见 [`runtime-pitfalls`](../../.claude/skills/runtime-pitfalls/SKILL.md) § 一。

---

## M8 · feature 改名 · 三处必须同步

### 症状
把 `feature_a` 重构成 `chat`，编译报：

```
hvigor ERROR: Module 'feature_a' not found.
```

### 排查
搜遍代码，发现**三处** `feature_a` / `chat`：

1. `build-profile.json5` 顶层 `modules[].name`
2. `chat/src/main/module.json5` 内 `module.name`
3. `chat/oh-package.json5` 内 `name`（被其他模块用 `@ohos/chat` 引用）

漏改其中之一就报。

### 修复
三处统一改完，加上 `entry/oh-package.json5` 的 `dependencies`（如果其他模块依赖它）。

### 教训
鸿蒙模块名在 4 处可能出现。本仓库新增 `tools/check-rename-module.sh` 自动校验三处一致：

```bash
bash tools/check-rename-module.sh
```

---

## M9 · 资源句柄释放（DB-001 / KIT-001 / KIT-002 类问题）

> 注：LCC 当前 BackupManager 用 `preferences` KV 序列化实现，**没用 RDB / ResultSet**，因此本节实际不源自该 app 的真踩坑。但 DB-001 提示"未来切到 relationalStore 时必须 ResultSet.close()"是工程通用真理；同时同类问题（http 实例不 destroy / ImageSource 不 release）在 LCC 的多模态调用链路确实出现过。本节作为**资源句柄释放范式**保留。

### 范式问题
鸿蒙原生句柄（ResultSet / RdbStore / ImageSource / http req / 文件 fd）若不 close/destroy/release，会触发：

- 单元测试 / 长跑场景报 "Too many open cursors" / "FD leak"
- AGC 提审稳定性测试 crash 率超 0.5% 阈值（被拒）

### 修复范式（以 RDB 为例）

```diff
 async loadAll(store: relationalStore.RdbStore): Promise<Backup[]> {
-  const rs = await store.querySql('SELECT * FROM backups');
-  const list: Backup[] = [];
-  while (rs.goToNextRow()) {
-    list.push(this.row2Backup(rs));
-  }
-  return list;
+  const rs = await store.querySql('SELECT * FROM backups');
+  try {
+    const list: Backup[] = [];
+    while (rs.goToNextRow()) {
+      list.push(this.row2Backup(rs));
+    }
+    return list;
+  } finally {
+    rs.close();
+  }
 }
```

http / ImageSource 同样 try / finally。

### 教训
任何"鸿蒙原生句柄"获取的瞬间都要规划释放。本仓库 scan-arkts 自动检测：
- `DB-001` ResultSet/RdbStore 取出未 close
- `KIT-001` `http.createHttp()` 用完未 destroy
- `KIT-002` ImageSource 解码后未 release

---

## M10 · API key HUKS 加密 · 一次迁移

### 症状
之前用 `Preferences.put('apiKey', plain)` 明文存。审核团队反馈：上架会被 AGC `SEC-001` 拒。

### 修复策略
不破坏老用户数据：**透明迁移**。

1. `loadApiKey()` 先读字段，看不像密文格式（base64 长度 + magic bytes）就当明文
2. 当场加密重写一次，下次再读就是密文
3. 新写都走 HUKS 加密

### 关键代码

```typescript
async loadApiKey(): Promise<string | null> {
  const v = await this.prefs.get('apiKey', '') as string;
  if (!v) return null;
  if (!this.looksEncrypted(v)) {
    // 历史明文，加密重写一次
    const ciphertext = await this.encrypt(v);
    await this.prefs.put('apiKey', ciphertext);
    await this.prefs.flush();
    return v;   // 这次先返回明文（已经加密回写了）
  }
  return await this.decrypt(v);
}

private looksEncrypted(s: string): boolean {
  // HUKS AES-GCM 输出 base64 后约 ≥ 64 字符且含特定字节
  return s.length >= 64 && /^[A-Za-z0-9+/=]+$/.test(s);
}
```

### 教训
任何"产品已经发布、改加密方案"都要做透明迁移。**关联**：[`runtime-pitfalls`](../../.claude/skills/runtime-pitfalls/SKILL.md) § 六、AGC `SEC-001`。

---

## M11 · Web 组件 markdown 渲染 · proxy 稳定实例

### 症状
Markdown 内嵌的 `<a href>` 点击 → H5 调 `window.linkOpener.open(url)` → ArkTS 端**第二次进入页面后失效**。

### 排查
在 ChatPage `build()` 里 inline 写：

```typescript
.javaScriptProxy({
  object: { open: (url: string) => router.pushUrl(...) },  // ← 字面量每次重建
  name: 'linkOpener',
  methodList: ['open'],
})
```

### 修复 diff

```diff
+class LinkOpenerProxy {
+  open(url: string): void { router.pushUrl({ url: 'pages/Browser', params: { url } }) }
+}
+
 @Entry @Component struct ChatPage {
+  private linkOpener: LinkOpenerProxy | null = null;
+
+  aboutToAppear(): void {
+    this.linkOpener = new LinkOpenerProxy();
+  }

   build() {
     Web({ ... })
       .javaScriptProxy({
-        object: { open: (url: string) => router.pushUrl(...) },
+        object: this.linkOpener!,
         name: 'linkOpener',
         methodList: ['open'],
       })
   }
 }
```

### 教训
`javaScriptProxy.object` 必须**整个组件生命周期内引用稳定**。详见 [`web-bridge`](../../.claude/skills/web-bridge/SKILL.md) § 一。

---

## M12 · OHPM 仓库 502 · 兜底

### 症状
临近上架准备阶段，`ohpm install` 报：

```
ohpm ERROR: 502 Bad Gateway · https://ohpm.openharmony.cn/ohpm/...
```

### 兜底
1. 注释掉 devDependencies 里非阻塞的（如 hammertest），让 build 通过
2. 切镜像：`ohpm config set registry https://ohpm.openharmony.cn/ohpm/`
3. 走本地缓存：`ohpm install --offline`（前提之前装过）
4. 如果只缺 dev 依赖，直接 `hvigorw assembleHap`（不依赖 dev 包）

### 教训
OHPM 仓库不是 100% 可用。production 关键依赖锁版本到本地缓存；非阻塞 dev 依赖出问题时**优先 unblock 主路径**而非死等仓库恢复。详见 [`runtime-pitfalls`](../../.claude/skills/runtime-pitfalls/SKILL.md) § 七。

---

## 总评

LCC 整个 M3-M12 路径上踩了 **15+ 真实坑**，分两大类：

| 类型 | 数量 | 自动扫描覆盖 | 必须靠 SKILL 引导 |
| --- | --- | --- | --- |
| ArkTS 语法层（编译期） | 8 | ✅ scan-arkts.sh 覆盖 | — |
| 运行时装配 / 工程层 | 7+ | ❌ grep 扫不出来 | ✅ runtime-pitfalls + 领域 SKILL |

**核心结论**：

- **scan-arkts.sh 抓 ArkTS 语法层**——已扩展到 ~25 条 grep 规则，假阳性低
- **SKILL 抓运行时装配陷阱**——靠 frontmatter 的 "激活条件" 让 AI 在改对应文件时自动激活
- **case-studies 抓真实战学到的教训**——比抽象规则更有说服力

---

## 贡献回来

如果你也跑通了一个真鸿蒙 app 并踩了不在本文档的坑，欢迎 PR：

- 加 `docs/case-studies/<your-app-type>.md`
- 每节用 **症状 / 错误信息 / 修复 diff / 教训** 四段式
- 关联到对应 SKILL 或新增 SKILL 触发条件
- 引用稳定 ID（`STATE-002` / `KIT-001` / `AGC-RJ-014` 等）
