# Case Study · 鸿蒙端对齐安卓 (React Native) 上游 — 多阶段迁移笔记

> **来源声明**：本笔记基于一个真实鸿蒙客户端项目（化名 PHC = Paseo Harmony Client），在 2026-05 完成"对齐上游 Expo/React Native 安卓端 UI 与协议"系列工作的踩坑记录。原项目代码已开源（[github.com/Octo-o-o-o/paseo-harmony](https://github.com/Octo-o-o-o/paseo-harmony)），本笔记**摘录可复用的工程经验**，**为可读性做了范型化处理**——具体里程碑的修复 diff 是从真实 commit 中提炼的代表性案例，不一定 1:1 对应该 app 的实际代码。
>
> 每章结构：**问题症状 → 根因诊断 → 修复路径 → 一句话教训**。
>
> 关联 SKILLS：[`arkts-rules`](../../.claude/skills/arkts-rules/SKILL.md) / [`runtime-pitfalls`](../../.claude/skills/runtime-pitfalls/SKILL.md) / [`state-management`](../../.claude/skills/state-management/SKILL.md)

---

## 工程背景

PHC 是一个鸿蒙端代码 agent 远程控制 app，对应安卓上游是 Expo/React Native 实现的 `paseo` 移动客户端（同协议、同 daemon）。鸿蒙端用 ArkTS / ArkUI 重写，**协议层 100% 复用上游 WebSocket message schema**。

```
PHC/
├── protocol/             # Messages.ets / Builders.ets / Parsers.ets — 协议 wire-format
├── runtime/              # DaemonClient.ets / HostRuntimeController.ets / TimelineReducer.ets
├── state/                # SessionStore / DraftStore / AttachmentStore / CheckoutStore（per-host 隔离）
├── components/           # MessageBubble / Composer / AttentionBanner / Sessions UI / ...
├── pages/                # Splash → Welcome / OpenProject (Sessions) / Workspace / Settings
└── entry/                # EntryAbility + Navigation
```

阶段：Phase 0-5 协议地基 + 基础 UI；Phase 6+ Sprint 池（Terminal / Theme / Git/PR / File / Voice / Push / a11y / Provider catalog / NewWorkspace / Subagent / 平板 / 折叠屏）；Phase A 用户实测后 3 张安卓截图深度对齐；Phase B Codex review 后补 8 项核心功能。

---

## 阶段一 · Splash → 主入口的"白屏循环"陷阱

### 症状

新装应用进入 Splash → 自动跳 Welcome 工作正常；但**已有 host 的用户**点项目列表的 X 关闭按钮后**白屏**，且 hilog 无 crash。

### 根因（双层）

**第一层**：Splash 用 `replacePathByName('open-project')` 替换自己 → OpenProject 是 NavPathStack **唯一一层**。

**第二层**：OpenProject 关闭按钮调 `pathStack.pop()` 无条件出栈 → stack 为空 → Navigation 没有 NavDestination 可显示 → 白屏（不是 crash）。

### 修复路径

```typescript
// ❌ 简陋版本（白屏）
Text('x').onClick(() => this.pathStack?.pop())

// ✅ 必须做 size guard + 安全回退
private handleCloseClick(): void {
  if (this.pathStack === null) return;
  if (this.pathStack.size() > 1) {
    this.pathStack.pop();
    return;
  }
  // 已是栈底：跳 welcome 而非 pop 到空
  try {
    this.pathStack.replacePathByName('welcome', JSON.parse('{}') as Object, false);
  } catch (e) {
    this.pathStack.pushPath({ name: 'welcome' }, false);
  }
}
```

### 一句话教训

**所有 `pop` 必须 `size() > 1` guard**；Splash 用 `replacePathByName` 是标准模式，但目标页都要假设自己可能是栈底。详见 [`runtime-pitfalls` § 十](../../.claude/skills/runtime-pitfalls/SKILL.md)。

---

## 阶段二 · emoji / Unicode 高码位字符渲染不可靠

### 症状

设计稿照搬安卓上游的 lucide-react-native 图标语义：
```typescript
Button('⌕')   // Search
Button('▣')   // Terminal
Button('📁')  // Files
Button('🎙')  // Voice
Button('⋯')   // More
```
真机（Mate 70 Pro / HarmonyOS 6.1）显示成 `c 口 C I . !` 之类的乱字符；某些 emoji 直接显示空白方框。

### 根因

鸿蒙系统字体（HarmonyOS Sans）对 Unicode 覆盖**有限**：
- ✅ 必支持：ASCII / Latin-1 / CJK 中文 / 部分 BMP 基础符号
- ❌ 不支持：大多数 emoji（U+1F300+）、Misc Technical Symbols 部分（U+22xx、U+231x、U+25xx）

### 修复路径（迭代两轮）

**第一轮**：所有 emoji 改为中文单字 / ASCII
```typescript
Button('搜')  // Search → 中文
Button('终')  // Terminal → 中文
Button('Git') // Git → 直接 ASCII
Button('文')  // Files → 中文
Button('音')  // Voice → 中文
Button('...') // More → 三个 ASCII period
```
真机显示：`搜 终 .. 文 音 .` — `Git` 被截断成 `..`，`...` 被截断成 `.`。

**第二轮**（发现 Button 默认 padding 截断 — 详见阶段三）：
```typescript
// Button → Text + onClick
Text('Git').width(44).height(44).textAlign(TextAlign.Center).onClick(...)
Text('...').width(44).height(44).textAlign(TextAlign.Center).onClick(...)
```
真机显示：`搜 终 Git 文 音 ...` ✅

### 验证策略

不确定 emoji / Unicode 是否可显示？**真机截图验证**：

```bash
hdc -t <serial> shell snapshot_display -f /data/local/tmp/s.jpeg
hdc -t <serial> file recv /data/local/tmp/s.jpeg /tmp/s.jpeg
```

### 一句话教训

**字体覆盖 != 编码合法**。上游用 lucide-react-native 等图标库不代表鸿蒙系统字体也能渲染同样字符。优先级：ASCII > 中文 > BMP 基础符号 > SymbolGlyph + sys.symbol > emoji。详见 [`runtime-pitfalls` § 十一](../../.claude/skills/runtime-pitfalls/SKILL.md)（`UI-001` 规则）。

---

## 阶段三 · ArkUI Button width 限定 + 多字符文本被默认 padding 截断

### 症状

按阶段二修复后还出现 `Button('Git').width(40)` 显示成 `..`（两个点）—— "Git" 三个字符明明能放下却被 ellipsis 截断。

### 根因

ArkUI `Button` 有默认 horizontal padding ~16px 两侧。`width(40)` 减去 32px padding 后文本可用区只剩 **~8px**，连 3 个 ASCII 字符（≈ 24-36px）都放不下。

### 修复

对 small icon button 类用例，用 `Text + .onClick` 替代 `Button`：

```typescript
// ❌ Button 限 width + 多字符
Button('Git').fontSize(FontSize.xs).width(40)

// ✅ Text 无 default padding
Text('Git')
  .fontSize(FontSize.base)
  .fontColor(this.colors.foreground)
  .width(44).height(44)
  .textAlign(TextAlign.Center)
  .accessibilityText('Git panel')
  .onClick(() => this.showCheckout = true)
```

### 一句话教训

小按钮（icon-button 风格）一律 `Text + onClick`；只有需要 system-level 按钮视觉（圆角 / pressed state / disabled state）时才用 `Button`。详见 [`runtime-pitfalls` § 十二](../../.claude/skills/runtime-pitfalls/SKILL.md)（`UI-002` 规则）。

---

## 阶段四 · "看不到历史 session — 只能创建新的"的修复链路

### 症状

用户从 Sessions 列表点 `Octo-o-o-o/OctoDesk` workspace card → 进入 Workspace 页面 → 看到的不是历史对话，而是 `Create new agent` 表单。但其实该 workspace 有 1 个 agent。

### 根因（双层）

**第一层 — UX bug**：Workspace `showCreateForm` 默认 `true`，controller 未 online 时立即显示空表单；等 online + fetch_agents 完才切到 timeline → 用户体验是"先空表单后历史"。

**第二层 — 协议字段不可靠**：daemon 返回的 `fetch_agents_response.entries[].agent.workspaceId` 字段在某些 workspace 类型（worktree / local_checkout）下**填的是 path 而不是 uuid**，或干脆 `undefined`。客户端按 `agent.workspaceId === ws.workspaceId` 严格 `===` 匹配会漏命中 → `agentsByWorkspace[wsId]` 永远是空 → 进 Workspace 时 fetch_agents 也按 workspaceId 严格过滤 → 仍空 → CreateAgentForm。

### 修复路径（4 层 fallback）

**1. 默认 state 改 loading 而非 create form**：
```typescript
@State showCreateForm: boolean = false;            // 之前 true
@State workspaceAgents: AgentDirectoryEntry[] = [];
@State hasFetchedAgents: boolean = false;
```

进入时显示 `LoadingAgentsState`，拉完 agents 列表后才决定显示 `WorkspaceAgentsList` 或 `CreateAgentForm`。

**2. Sessions 列表预拉每个 workspace 的 agents**：
按上层做一次 `fetch_agents`，结果归类到 `Map<workspaceId, AgentDirectoryEntry[]>`。

**3. 归类时三层匹配 fallback**（核心修复）：
```typescript
// 1) agent.workspaceId === ws.workspaceId 严格匹配
let matched = false;
if (agent.workspaceId !== undefined && agent.workspaceId !== '') {
  // ... find by id
}
// 2) agent.cwd === ws.workspaceDirectory ?? projectRootPath fallback
if (!matched && agent.cwd !== '') {
  // ... find by cwd
}
// 3) 都失败 → orphan agents
```

**4. 点 workspace card 时自动 resume 最近活跃 agent**：
```typescript
private openWorkspaceWithAutoResume(g: ProjectGroup, ws: WorkspaceEntry): void {
  const agents = g.agentsByWorkspace.get(ws.workspaceId);
  if (agents !== undefined && agents.length > 0) {
    // 按 lastUserMessageAt / updatedAt / createdAt desc 选最新
    const sorted = agents.slice().sort((a, b) =>
      agentLastActivityMs(b.agent) - agentLastActivityMs(a.agent));
    this.openWorkspace(ws.workspaceId, sorted[0].agent.id, ws.workspaceDirectory ?? '');
    return;
  }
  // 无 agents → 走原逻辑显示 CreateAgentForm
  this.openWorkspace(ws.workspaceId, '', ws.workspaceDirectory ?? '');
}
```

### 一句话教训

**daemon 返回的"应该是 uuid"的字段在 wire-format 上可能填 path** —— 任何严格 `===` 匹配都要有 cwd / displayName 等业务字段的 fallback 兜底。详见 [`runtime-pitfalls` § 十六](../../.claude/skills/runtime-pitfalls/SKILL.md)（`TYPES-007` 规则）。

---

## 阶段五 · 历史消息缺时间戳 — 路径绕过了 reducer

### 症状

resume 历史会话后，timeline 中的用户/助手消息**没有时间戳**；但 agent_stream 实时推的新消息有。

### 根因

鸿蒙端 timeline 有两条数据路径：
1. **流推**：`agent_stream` event → `TimelineReducer.apply` → 转发 item
2. **历史拉取**：`fetch_agent_timeline_response` → 应走 `TimelineReducer.applyFetchedEntries`

`applyFetchedEntries` 内部对每条 entry 调 `injectTimestamp(item, ts)`（ISO → epoch ms）。但 `Workspace.resumeExistingAgent` 写成了：
```typescript
const payload = await client.fetchAgentTimeline({ agentId });
for (let i = 0; i < payload.entries.length; i++) {
  this.session.appendTimelineItem(agentId, payload.entries[i].item);
  //                                          ^ 跳过 injectTimestamp
}
```

直接调 `SessionStore.appendTimelineItem` 绕过了 reducer → timestamp 没注入 → UI 拿不到。

### 修复

```typescript
// ✅
const payload = await client.fetchAgentTimeline({ agentId });
this.reducer.applyFetchedEntries(agentId, payload.entries);
```

### 一句话教训

**所有 store 写入应封死单一入口**（reducer）。Code review 时凡是看到 `store.append*` / `store.set*` 直接调，先质疑是否绕过了 reducer。详见 [`runtime-pitfalls` § 十四](../../.claude/skills/runtime-pitfalls/SKILL.md)（`STATE-011` 规则）。

---

## 阶段六 · Per-host store 必须按 serverId 隔离

### 症状

用户加 2 个 host（mac 本机 + 公司机）后切换 host 时，git checkout 状态、draft 草稿、attachment pending 列表互相覆盖。

### 根因

`CheckoutStore` 等单例最初用 `cwd` 做单 key 分桶。两 host 上恰好同 cwd（如 `~/project/foo`）→ 互相覆盖。

### 修复

key 改 `${serverId}:${cwd}` 联合：
```typescript
function keyOf(serverId: string, cwd: string): string {
  return serverId + ':' + cwd;
}

// 所有 API 加 serverId 参数
get(serverId: string, cwd: string): Entry | undefined;
setStatus(serverId: string, cwd: string, status: Status): void;
removeAllForHost(serverId: string): void;   // host 断开时清掉本 host 全部 entry
```

### Per-host store key 速查

| Store | key |
| --- | --- |
| `DraftStore` | `${serverId}:${agentId}` |
| `AttachmentStore` | `${serverId}:${agentId}` |
| `CheckoutStore` | `${serverId}:${cwd}` |
| `WorkspaceTabsStore` | `${serverId}:${workspaceId}` |
| `ProviderSnapshotStore` | `${serverId}` |
| `TerminalManager` | per `HostRuntimeController` instance |

### 一句话教训

**任何"per-host"语义的 store 必须以 serverId 为 key 前缀**。详见 [`runtime-pitfalls` § 十五](../../.claude/skills/runtime-pitfalls/SKILL.md)（`STATE-010` 规则）。

---

## 阶段七 · MessageBubble 对齐上游 — ExpandableBadge / status badge / metaRow

### 症状

初版 MessageBubble 把所有类型（user / assistant / reasoning / tool / todo / sub_agent / compaction / error）渲染成统一气泡 + 折叠头 → 视觉粗糙。

### 上游对照

安卓 `components/message.tsx`（3000+ 行）按 type 分发到不同子组件：

| 类型 | 安卓样式 | 鸿蒙等效 |
| --- | --- | --- |
| user | 右浮 surface3 浅灰气泡 / 圆角右上角小 / 下方 trailingRow (timestamp + copy) | 同上 |
| assistant | **无气泡背景**，全宽 markdown | 同上 |
| reasoning | ExpandableBadge "Reasoning" + 第一行预览 / 展开斜体灰字 | 同上 |
| tool_call | ExpandableBadge + status badge (彩色)：done绿/running黄/failed红/canceled灰 | 同上 |
| todo | ExpandableBadge "Tasks · 下一任务" + n/m counter / 展开 radio + line-through | 同上 |
| compaction | Divider 水平线 + 中间灰小字 | 同上 |
| error | Divider + 红字 | 同上 |
| sub_agent | 复用 tool 风格 | 同上 |

### 修复（重写 MessageBubble）

关键改动：
- `build()` 顶层 wrap Column container（详见阶段八）
- user / assistant 单独 builder；其他统一进 `expandableBadge(label, secondary, kind)`
- 颜色全走 `$r('app.color.paseo_*_bubble_bg')` 让 light/dark 自动切换
- 修资源色：user bubble bg 从蓝 `#0A84FF` 改 surface3 `#EEEEEF`；assistant bg 改 transparent

### 一句话教训

视觉对齐上游不是机械重画 UI，是**按 type → component 的分发 + 状态语义**（badge color、collapse default、copy 可用性）建立映射表，让所有类型都走自己的渲染路径。

---

## 阶段八 · `build()` 单 root container 硬约束

### 症状

修 MessageBubble 时写成：
```typescript
build() {
  if (this.bubbleStyle === 'system' || this.bubbleStyle === 'error') {
    this.centerBlock()
    return
  }
  Row() { ... }
}
```
编译报错：
```
In an '@Entry' decorated component, the 'build' method can have only one root node,
which must be a container component.
```

### 根因

ArkUI 硬约束：`build()` 顶层**必须恰好一个**容器组件（Column / Row / Stack / Flex / Grid 等）。多分支顶层裸语句直接违反约束。

### 修复

```typescript
build() {
  Column() {
    if (this.bubbleStyle === 'system' || this.bubbleStyle === 'error') {
      this.centerBlock()
    } else {
      Row() { ... }
    }
  }
  .width('100%')
}
```

### 一句话教训

**`build()` 顶层永远是单一容器**；分支放在容器内或 builder 函数内。`@Builder` 子函数不受此限制。详见 [`runtime-pitfalls` § 十三](../../.claude/skills/runtime-pitfalls/SKILL.md)（`UI-003` 规则）。

---

## 阶段九 · 协议消息 envelope 双层 vs 顶级 — 必查 SessionInboundMessageSchema

### 症状

实现 `register_push_token` 后真机推 token，daemon 不响应。Logger 看 client 已发，但 daemon hilog 未收到。

### 根因

上游 `messages.ts:1881` 显示 `RegisterPushTokenMessageSchema` 是 `SessionInboundMessageSchema` 的成员 → daemon 期望 **session 双层包装**：

```json
{
  "type": "session",
  "message": { "type": "register_push_token", "token": "xxx..." }
}
```

但客户端实现误以为是顶级消息：
```typescript
// ❌ 直接发顶级
await transport.send(JSON.stringify({ type: 'register_push_token', token }));
```

### 修复

```typescript
// ✅ 走 envelope 双层
export function buildRegisterPushToken(token: string): WSSessionInbound {
  const msg: RegisterPushTokenMessage = { type: 'register_push_token', token };
  return envelope(msg);   // → { type: 'session', message: msg }
}
```

### 一句话教训

**所有 client → server message 加进 builder 之前先查上游 `SessionInboundMessageSchema` 列表**：
- 在列表里 → 必须 `envelope()` 包装
- 不在列表里（如 `hello`）→ 顶级
- 误判 → daemon 静默丢弃，调试极困难

---

## 阶段十 · Codex review 揪出的 3 类架构隐患

完成 Phase B 设计方案后，用 Codex (`subagent_type: codex:codex-rescue`) 做独立 architecture review。它揪出 3 个我没意识到的隐患：

1. **`SessionStore.AgentView` 缺字段**：方案要在 attention banner 用 `agent.requiresAttention`，但 AgentView 还没有这字段 → 整个 banner UI 数据源不存在。

2. **`resumeExistingAgent` 跳过 reducer**：见阶段五 — timestamp 注入被绕过。

3. **`ProviderSnapshotStore` map 不响应**：内部 `Map` 数据变化不触发 UI rebuild（ArkUI `@State` 只追踪引用替换）。

### 流程教训

**外部 review 极有价值**。Codex / 另一个 AI / 资深人类 review 一份方案 PR，往往能在 30 分钟内揪出 3-5 个你自己思维盲区里的隐患。

**最稳定的 review prompt 框架**：
```
背景：[项目坐标 + 已实现内容]
我打算做：[方案点]
请评估：
1. ROI 排序是否合理？
2. 实施路径是否有架构隐患？
3. 有更高 ROI 但被遗漏的项吗？
4. 鸿蒙特有约束下哪一项最容易踩坑？
5. 建议的实施顺序（含估算）。
```

---

## 阶段十一 · "提前拉数据 vs 进页再拉"的选择

### 症状

第一版 Sessions 列表只显示 workspace；点 workspace card 进 Workspace 后才二次 `fetch_agents` → 用户经历 Loading… 闪现 → 创建表单闪现 → 才看到历史 timeline。

### 修复策略

**Sessions 列表阶段一次性预拉所有 agents**（不分 workspace），按 workspaceId/cwd 归类好 `Map<workspaceId, AgentDirectoryEntry[]>` 存在父 page state；点 workspace card 时直接选最近活跃 agent 的 id 作为路由参数传给 Workspace → Workspace 跳过 `fetch_agents` 直接 `resumeExistingAgent`。

### 一句话教训

**列表页是预拉一次拿全的好时机**；详情页应假设数据已 ready，只做"恢复已有上下文 + 后续增量更新"，不该重复列表页做过的拉取。

---

## 阶段十二 · `Record<string, Object>` 字面量 ArkTS 编译禁用

### 症状

写 `const param: Record<string, Object> = { serverId, workspaceId };` 报：
```
arkts-no-untyped-obj-literals
```

### 原因

ArkTS 严格类型禁止裸对象字面量赋给 `Record` 类型（即使有类型注解）。

### 修复（实战 hack）

```typescript
// ✅ 用 JSON.parse 拿一个 plain object 然后逐字段 set
const param: Record<string, Object> = JSON.parse('{}') as Record<string, Object>;
param.serverId = this.serverId;
param.workspaceId = this.workspaceId;
this.pathStack?.pushPath({ name: 'workspace', param: param as Object });
```

可以抽出 helper：
```typescript
function emptyRecord(): Record<string, Object> {
  return JSON.parse('{}') as Record<string, Object>;
}
```

### 一句话教训

ArkTS 不允许任何 untyped object literal。透传 daemon 嵌套 JSON 时这个限制特别讨厌 — 准备好 `emptyRecord()` helper。详见 `TYPES-005` 规则。

---

## 阶段十三 · ArkTS 类型推断 union | null 在 if 内变 never

### 症状

```typescript
let matchedGroup: ProjectGroup | null = null;
// ... 给 matchedGroup 赋值 ...
if (matchedKey !== null && matchedGroup !== null) {
  matchedGroup.agentsByWorkspace.set(...);
  //          ^^^^^^^^^^^^^^^^^^
  // 编译错: Property 'agentsByWorkspace' does not exist on type 'never'.
}
```

### 原因

ArkTS 类型窄化在 `let` + 复杂控制流时有时把 `Group | null` 在 if 内推成 `never`（甚至 if 内显式 `!== null` 也不行）。

### 修复

显式 `as` cast 重新声明：
```typescript
if (matchedKey !== null && matchedGroup !== null) {
  const g: ProjectGroup = matchedGroup as ProjectGroup;   // ← 显式 cast
  const k: string = matchedKey as string;
  g.agentsByWorkspace.set(k, ...);
}
```

### 一句话教训

ArkTS 类型推断有时比 TypeScript 更激进；`let x: T | null = null; ...; if (x !== null) { x.foo }` 不可靠 — 必要时用临时 `const safe = x as T` cast 显式断言。详见 `TYPES-006` 规则。

---

## 阶段十四 · 真机部署 + screenshot 工作流

整套 hap 真机调试流程在本项目（含 hdc 命令）已稳定：

```bash
# 1. 真机部署（强制停 + 重装 + 启动）
hdc -t <serial> shell aa force-stop <bundle>
hdc -t <serial> install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc -t <serial> shell aa start -a EntryAbility -b <bundle>

# 2. 截图取证
hdc -t <serial> shell snapshot_display -f /data/local/tmp/s.jpeg
hdc -t <serial> file recv /data/local/tmp/s.jpeg /tmp/s.jpeg

# 3. 看 app 进程 + ability 状态
hdc -t <serial> shell "aa dump -l 2>&1" | grep -B 1 -A 5 <bundle>
hdc -t <serial> shell hilog -x | grep -E "<bundle>|<pid>" | head -30
```

**关键陷阱**：
- `snapshot_display -f` 必须 `.jpeg` 后缀（`.png` 报错 "filename invalid"）
- `uinput -T -c <x> <y>` touch 经常 hit miss（坐标系不准）→ 不要自动化操作，让用户手动点
- 鸿蒙模拟器（`127.0.0.1:5555`）签名要求与真机不同（"install sign info inconsistent"，code `9568332`）→ 仅在真机验证

---

## 总结 · 鸿蒙端对齐 RN 上游的核心方法论

1. **协议层 100% 复用上游 schema**，client UI 重写。schema 字段名 / 双层 envelope / 字段缺省值都要按 wire-format 而非 client 内部约定。
2. **UI 视觉对齐不是机械复制**，是建立 type → component → 状态 badge 的映射表。
3. **每个交互（点击 / 滑动 / 返回）都要测**真机：因为字体 / 默认 padding / Navigation 行为可能与预期不同。
4. **State store 一开始就按 serverId 隔离**，否则切 host 时回头改架构成本极高。
5. **方案文档 → Codex review → 修订 → 实施**：外部 review 必跑。
6. **emoji 字符 / Unicode 高码位**：默认假设鸿蒙系统字体不支持，先验证再用。
7. **ArkTS 编译错误信息有限**：写代码时主动避雷 `arkts-no-*` 规则比 build 后改成本低 10x。

---

## 引用规则

本笔记涉及的规则编号（详见 [`arkts-rules/references/spec-quick-ref.md`](../../.claude/skills/arkts-rules/references/spec-quick-ref.md)）：

- `NAV-001` NavPathStack pop 空 stack 白屏
- `UI-001` emoji / Unicode 高码位字符不显示
- `UI-002` Button width 限定 + 默认 padding 截断
- `UI-003` build() 单 root container
- `STATE-010` Per-host store serverId 隔离
- `STATE-011` Timeline 写入绕过 reducer 导致 timestamp 丢失
- `TYPES-005` `Record<string, Object>` 字面量 → `JSON.parse('{}')` hack
- `TYPES-006` ArkTS union | null 在 if 内推成 never
- `TYPES-007` daemon "uuid" 字段不可靠 → cwd fallback
