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
| `STATE-009` | `this.cache.set('k', v)` Map/Set 就地 mutation | `const next = new Map(this.cache); next.set(...); this.cache = next` | 中频 |

---

## 三、Kit / 性能 / 安全

| 规则 ID | 反模式 | 正确写法 |
| --- | --- | --- |
| `KIT-001` | `http.createHttp()` 用完没 `destroy()` | 加 `req.destroy()` 释放 |
| `PERF-001` | `arr.forEach(async ...)` | 并发 `Promise.all(arr.map(async ...))` 或顺序 `for-of` |
| `SEC-001` | 硬编码看似 token / api-key / password 的字符串 | 挪到 EncryptedPreferences / 环境变量 |
| `COMPAT-001` | 用 API 21+ 新 Kit 但无 `canIUse` 守护 | `if (canIUse('SystemCapability.Foo')) { ... }` |

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
