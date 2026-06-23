# ArkTS 1.2 规范快查 + 规则映射

> 本文是 `arkts-rules` skill 的规范源头。每条 `ARKTS-*` / `STATE-*` 规则对应一节官方规范，AI 在 review / 修复时**必须引用条款 ID**而非凭印象。
>
> 规范源头（华为开发者联盟 / OpenHarmony 官方）：
> - 编码风格：<https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/typescript-to-arkts-migration-guide>
> - ArkTS 语言规范：`upstream-docs/openharmony-docs/zh-cn/application-dev/quick-start/arkts-coding-style-guide.md`
> - 迁移背景：`upstream-docs/.../quick-start/arkts-migration-background.md`

---

## 一、ArkTS 严格语法（编译期阻断）

| 规则 ID | 官方规范条款 | 反模式 | 正确写法 | 验证方式 |
| --- | --- | --- | --- | --- |
| `ARKTS-001` | arkts-no-any-unknown | `let x: any = ...` | `let x: ConcreteType = ...` | scan-arkts.sh 内联 + `hvigorw codeLinter` |
| `ARKTS-002` | arkts-no-untyped-obj-literals | `const o = { a:1 }` | 先 `class O {...}` 再 `const o: O = {...}` | hvigorw 报 `arkts-no-untyped-obj-literals` |
| `ARKTS-003` | arkts-no-props-by-index | `obj['key']` | 类 → 点访问；动态 → `Map<K,V>.get(k)` | scan-arkts.sh 18 条之一 |
| `ARKTS-004` | arkts-no-destruct-assignment | `const {a, b} = obj` | `const a = obj.a; const b = obj.b;` | scan-arkts.sh + hvigorw |
| `ARKTS-005` | arkts-no-func-expr | `const f = function(x){...}` | `const f = (x: T): R => {...}` | scan-arkts.sh |
| `ARKTS-006` | arkts-no-private-identifiers | `class C { #priv: T }` | `class C { private priv: T }` | hvigorw |
| `ARKTS-007` | arkts-no-regexp-literals | `/x/g` | `new RegExp('x', 'g')` | scan-arkts.sh + hvigorw |
| `ARKTS-008` | arkts-no-delete | `delete obj.x` | 字段类型 `T \| null`，赋 `null` | scan-arkts.sh + hvigorw |
| `ARKTS-009` | arkts-no-for-in | `for (const k in obj)` | `for (const k of Object.keys(obj))` | scan-arkts.sh + hvigorw |
| `ARKTS-010` | arkts-no-uninit-class-fields | `class A { name: string; }` | `class A { name: string = ''; }` 或 constructor 赋值 | hvigorw |
| `ARKTS-011` | BusinessError 处理 | `catch (e) { throw e.message }` | `catch (e) { const err = e as BusinessError; ... }` | review skill 引用 |
| `ARKTS-012` | hilog 而非 console | `console.log(...)` | `hilog.info(DOMAIN, 'tag', '%{public}s', s)` | scan-arkts.sh |
| `ARKTS-014` | Kit 化 import 推荐 | `from '@ohos.net.http'` | `from '@kit.NetworkKit'` | scan-arkts.sh |
| `ARKTS-015` | arkts-no-polymorphic-unops | `+'42'` | `parseInt('42', 10)` 或 `Number('42')` | scan-arkts.sh + hvigorw |
| `ARKTS-016` | 空 catch 块吞错 | `catch (e) {}` | 至少 `hilog.error(...)` 或重抛 | scan-arkts.sh |

---

## 二、状态管理（运行时但 UI 不刷新）

| 规则 ID | 反模式 | 正确写法 | 数据 |
| --- | --- | --- | --- |
| `STATE-001` | 同文件混用 V1（`@Component`）与 V2（`@ComponentV2`） | 一文件一选 | 编译报错或运行时混乱 |
| `STATE-002` | `this.list.push(x)` 等数组就地 mutation | `this.list = [...this.list, x]` | **42% 的 LLM 错误来源**（ArkEval） |
| `STATE-003` | `this.user.name = 'A'` 对象字段直改（无 `@Observed`） | `this.user = { ...this.user, name: 'A' }` 或类加 `@Observed` | 高频 |
| `STATE-006` | `Toggle({ on: this.x })` 父子双向绑定丢 `$$` | `Toggle({ on: $$this.x })` | 常见 |
| `STATE-008` | `build()` 内调 `console`/`fetch`/`await`/`setTimeout` | 副作用挪到 `aboutToAppear` / `onClick` 等 | 高频 |
| `STATE-009` | `this.cache.set(...)` / `this.set.add(...)` Map/Set 就地 mutation（`set`/`delete`/`clear`/`add`） | `const next = new Set(this.set); next.add(...); this.set = next` | 中频 |
| `STATE-010` | Per-host store 用单 key（如 `cwd`）分桶 → 多 host 状态串扰 | key 改 `${serverId}:${cwd}` 联合 | 多 host 必现 |
| `STATE-011` | `SessionStore.appendTimelineItem` 直接写绕过 `TimelineReducer.applyFetchedEntries` → timestamp 等元数据丢失 | 历史拉取也走 reducer：`reducer.applyFetchedEntries(agentId, entries)` | 中频（绕路径常见） |

---

## 三、UI / Navigation / 类型系统（新增）

| 规则 ID | 反模式 | 正确写法 | 说明 |
| --- | --- | --- | --- |
| `NAV-001` | `NavPathStack.pop()` 到空 stack → 白屏 | `if (size > 1) pop(); else replacePathByName('safe-fallback')` | Splash → replacePathByName 后目标页是栈底时必踩 |
| `UI-001` | `Button('🎙') / Text('⌕') / Text('⋯')` 等 emoji 或 BMP 高码位字符在鸿蒙系统字体不显示，fallback 成空方框 / 错字符 | 用 ASCII / 中文单字 / BMP 基础符号（`≡` `·` `→` `↓` `×` `✓`）/ SymbolGlyph + `sys.symbol.*` | 安卓上游用 lucide-react-native，鸿蒙照搬必踩 |
| `UI-002` | `Button('Git').width(40)` — Button 默认 padding ~16px 两侧吃掉 width，多字符文本被 ellipsis 截断 | 用 `Text + onClick` 替代（无 default padding），或 `Button.padding({ left: 4, right: 4 }).width(60)` | 头部 icon-button 必踩 |
| `UI-003` | `build()` 内多分支顶层组件（`if {} ... Row {}` 并列）→ 编译报错 "build can have only one root node" | 整体 wrap 进单一 Column / Row 外层；分支放进 builder 函数内 | ArkUI 硬约束 |
| `TYPES-005` | `const x: Record<string, Object> = {};` 字面量 → `arkts-no-untyped-obj-literals` 编译错 | `const x: Record<string, Object> = JSON.parse('{}') as Record<string, Object>` 或先 `class T {...}` | 透传 daemon 嵌套 JSON 时常见 |
| `TYPES-006` | `let g: Group \| null = null; if (g !== null) { g.foo }` —— ArkTS 在 if 内可能把 g 推成 never | `const safeG = g as Group; safeG.foo` 显式 cast | ArkTS 类型窄化 + null union 时偶发 |
| `TYPES-007` | 把"应该是 uuid"的字段（如 `agent.workspaceId`）当严格 uuid 用 → daemon 在某些 workspace 类型下填 path 字符串，导致 `===` 严格匹配漏命中 | 始终用 cwd 等业务字段做 fallback 匹配 | 客户端 / daemon wire-format 不变契约时必踩 |

---

## 四、Kit / 性能 / 安全 / 数据库 / 上架

| 规则 ID | 反模式 | 正确写法 | 自动扫描 |
| --- | --- | --- | --- |
| `KIT-001` | `http.createHttp()` 用完没 `destroy()` | 加 `req.destroy()` 释放 | ✅ |
| `KIT-002` | ImageSource 解码后未 `.release()` | `imageSource.release()` 释放原生缓冲 | ✅ |
| `KIT-003` | `import('@kit.ScanKit')` 在 HarmonyOS 6.x 真机 default export 解析不稳定 | dual-import `@hms.core.scan.scanBarcode` + `@hms.core.scan.scanCore`，显式取 `.default` | ✅ |
| `KIT-004` | `ScanType.QRCODE` 在 HarmonyOS 6.x 已改名 `QR_CODE`，旧名解析为 `undefined` 导致 `startScanForResult` BusinessError 401 | `ScanType.QR_CODE`（旧名不存在；AI 训练数据全用 QRCODE 必须显式覆盖） | ✅ |
| `PERF-001` | `arr.forEach(async ...)` | 并发 `Promise.all(arr.map(async ...))` 或顺序 `for-of` | ✅ |
| `PERF-002` | 长列表用 `ForEach` 而非 `LazyForEach` | `LazyForEach + IDataSource`（> 50 项时） | ✅ |
| `SEC-001` | 硬编码看似 token / api-key / password 的字符串（≥ 16 字符） | 挪到 EncryptedPreferences / 环境变量 | ✅ |
| `SEC-002` | `hilog %{public}` 输出敏感字段（token / 身份证 / password 等） | 用 `%{private}` 或脱敏 `mask()` 后再打 | ✅ |
| `SEC-007` | `MD5` / `SHA1` / `DES` 弱算法 | SHA-256+ / AES-GCM（`@kit.CryptoArchitectureKit`） | ✅ |
| `CSPRNG-001` | `Math.random()` 用于 IV / nonce / signature / PKCE verifier 等加密上下文（路径 `/security/` 或 `/crypto/` → High；含 `cryptoFramework` / `nonce` / `aesGcm` / `huks` / `hmac` 等关键字 → High；否则 Medium） | `cryptoFramework.createRandom().generateRandomSync(N)`；inline-suppress: `// scan-ignore: CSPRNG-001` | ✅ |
| `CSPRNG-002` | HUKS `HUKS_TAG_IV` / `HUKS_TAG_NONCE` 同文件无 `cryptoFramework.createRandom` 引用（GCM nonce 重用比 IV 更致命，泄漏认证密钥流） | nonce / IV 必须从 CSPRNG 取；inline-suppress 仅适用来自可信跨文件封装 | ✅ |
| `DB-001` | ResultSet / RdbStore 取出后未 `.close()` | `try { ... } finally { rs.close() }` | ✅ |
| `COMPAT-001` | 用 API 21+ 新 Kit 但无 `canIUse` 守护 | `if (canIUse('SystemCapability.Foo')) { ... }` | ✅ |
| `AGC-RJ-014` | UI 硬编码中文字符串 | `Text($r('app.string.xxx'))` + 资源文件 | ✅ |
| `STATE-006` | V1 子组件 `@Link`，调用方丢 `$$` | `Toggle({ on: $$this.x })` 而非 `Toggle({ on: this.x })` | ✅ |

---

## 四、AI 引用规范的"硬约束"

当 AI 在 ArkTS 代码上下文工作时：

1. **回答涉及 ArkTS 语法 / 装饰器时**，必须在解释中引用对应 ID（如 "这是 STATE-002 反模式"）
2. **被 hook 命中违规时**，回复结构必须是：
   - 引用规则 ID
   - 引用本文表格的"正确写法"列
   - 不要"另写一个看上去对的版本"
3. **找不到对应规则时**，去 `01-language-arkts/02-typescript-to-arkts-migration.md` 查 `arkts-no-*` 编号；都查不到再说"我不确定"

---

## 五、维护说明

新规则纳入流程：

1. 在 `tools/hooks/lib/scan-arkts.sh` 加 grep 模式
2. 在 `.claude/skills/harmonyos-review/references/checklist.md` 加 review 条目
3. 在本文件第一/二/三表中加映射
4. 在 `tools/hooks/test-fixtures/` 加 fixture
5. 在 CHANGELOG 注明 ID

ID 命名规范：

- `ARKTS-NNN`：编译期 ArkTS 语法约束
- `STATE-NNN`：运行时状态管理
- `KIT-NNN`：Kit 使用规范
- `PERF-NNN`：性能反模式
- `SEC-NNN`：安全 / 隐私
- `COMPAT-NNN`：API 版本兼容
- `LIFE-NNN`：生命周期资源管理
- `DB-NNN`：数据库 / 持久化
- `PERM-NNN`：权限管理
- `AGC-RJ-NNN`：上架审核拒因（已存在于 `07-publishing/`）
