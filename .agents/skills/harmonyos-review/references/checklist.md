# 鸿蒙代码审查 · 完整 Checklist

> 10 大类、75 条具体扫描点。每条带稳定 ID（如 `SEC-001`、`ARKTS-002`），便于 AI 在报告中引用。
>
> **v0.5.1 ID 对齐说明**：本清单曾与 scanner（`tools/hooks/lib/scan-arkts.sh`）/ [`spec-quick-ref.md`](../../arkts-rules/references/spec-quick-ref.md) 对 `STATE-009/010`、`KIT-002/003/004` 各自定义不同语义。现以 **scanner 语义为准**（下游代码里的 `// scan-ignore:` 抑制注释与历史报告引用的都是 scanner 语义），本清单侧改号：原 STATE-009（@Watch 死循环）→ `STATE-012`；原 STATE-010（AppStorage）→ `STATE-013`；原 KIT-002（File 流式）→ `KIT-008`；原 KIT-003（ImageSource release）→ `KIT-002`；原 KIT-004（通知）→ `KIT-009`。
>
> 另有案例沉淀的 `NAV-*` / `UI-*` / `TYPES-*` / `CSPRNG-*` / `STRING-JSON-*` 编号（scanner / 运行时陷阱侧），映射见 [`spec-quick-ref.md`](../../arkts-rules/references/spec-quick-ref.md)，报告中同样可直接引用。

## 1. 安全合规（SEC）

| ID | 检查项 | 严重级 |
| --- | --- | --- |
| SEC-001 | 代码 / 配置中无硬编码密钥、口令、API Key、JWT secret | Critical |
| SEC-002 | 敏感数据（口令、TOKEN）只在内存或加密存储中，不在 hilog / log 中明文 | Critical |
| SEC-003 | 网络请求强制 HTTPS（除非显式 dev 配置） | High |
| SEC-004 | WebView 启用 `allowFileAccess=false`、`allowUniversalAccessFromFileURLs=false` | High |
| SEC-005 | SQL 拼接全部参数化（`?` 占位），无字符串拼接生成 SQL | High |
| SEC-006 | `intent` / `Want` 数据严格类型校验，对外部传入做边界检查 | High |
| SEC-007 | 加密算法不用 MD5 / SHA1 / DES（用 SHA-256+、AES-GCM） | Medium |
| SEC-008 | 文件读写在 sandbox 内，未越权访问外部存储 | High |

## 2. ArkTS 语法（ARKTS）

| ID | 检查项 | 严重级 |
| --- | --- | --- |
| ARKTS-001 | 无 `any` / `unknown` / `var` | High |
| ARKTS-002 | 对象字面量都有显式 class / interface 类型注解 | High |
| ARKTS-003 | 无 `obj['key']` 动态索引（除非 obj 是 Map / Record） | Medium |
| ARKTS-004 | 无解构赋值 `const {a,b} = obj` 或函数参数解构 | Medium |
| ARKTS-005 | 无 `function` 表达式（用箭头） | Low |
| ARKTS-006 | 无 `#` 私有字段（用 `private` 关键字） | Low |
| ARKTS-007 | 无 `/regex/` 字面量（用 `new RegExp`） | Medium |
| ARKTS-008 | 无 `delete` 操作符 | Medium |
| ARKTS-009 | 无 `for...in`（用 `for-of` / 普通 `for`） | Medium |
| ARKTS-010 | 类字段在声明或 constructor 中初始化 | High |
| ARKTS-011 | 错误处理用 `BusinessError` 类型断言 | Medium |
| ARKTS-012 | 日志统一用 `hilog`（`%{public}` 或 `%{private}`），不用 `console.*` | High |
| ARKTS-013 | 无魔法数字（≥ 100 的常量定义为 `const` 或 enum） | Low |
| ARKTS-014 | import 走 `@kit.*`，不用 `@ohos.*` 旧式 | Medium |

## 3. 状态管理（STATE）

| ID | 检查项 | 严重级 |
| --- | --- | --- |
| STATE-001 | 单 `.ets` 文件不混用 V1（`@Component`）与 V2（`@ComponentV2`）装饰器 | Critical |
| STATE-002 | 数组变更替换引用（`this.list = [...]`），无 `push/splice/sort` 就地 mutation | High |
| STATE-003 | 对象字段变更替换对象（`this.x = {...this.x, ...}`），除非类有 `@Observed`/`@ObservedV2` | High |
| STATE-004 | V1 引用对象响应：类标 `@Observed`，子组件用 `@ObjectLink` | High |
| STATE-005 | V2 引用对象响应：类标 `@ObservedV2`，字段标 `@Trace` | High |
| STATE-006 | V1 `@Link` 调用方传 `$$x`，不是 `x` | Medium |
| STATE-007 | V2 `@Event` 字段必须有默认值 `() => {}` | Medium |
| STATE-008 | `build()` 是纯函数，不调 await / setState / 副作用 | High |
| STATE-009 | Map / Set 状态变更替换实例（`new Map(this.cache)` 后再赋值），无 `set/delete/clear/add` 就地 mutation | High |
| STATE-010 | Per-host / per-workspace 语义的单例 store 用 `${serverId}:${...}` 联合 key 分桶，不用单 key（多 host 状态串扰） | Medium |
| STATE-011 | 所有 store 写入走 reducer / action 单一入口，不绕过（绕路径丢 timestamp 等元数据） | Medium |
| STATE-012 | `@Watch` / `@Monitor` 回调内不修改触发字段（无限循环）（v0.5.1 前编号 STATE-009） | High |
| STATE-013 | 跨页面共享状态用 AppStorage / LocalStorage，不用全局变量（v0.5.1 前编号 STATE-010） | Medium |

## 4. 生命周期（LIFECYCLE）

| ID | 检查项 | 严重级 |
| --- | --- | --- |
| LIFE-001 | `aboutToDisappear` 中取消订阅、关闭定时器、销毁 Worker | High |
| LIFE-002 | 长任务在 `aboutToDisappear` 时检查 cancellation token | Medium |
| LIFE-003 | `EntryAbility.onDestroy` 释放共享资源（数据库连接、文件句柄） | High |
| LIFE-004 | 页面跳转前清理对话框、Toast、Loading 状态 | Medium |
| LIFE-005 | NAPI 模块在 `onDestroy` 调用对应 `release` / `dispose` | High |

## 5. 数据库 / 持久化（DB）

| ID | 检查项 | 严重级 |
| --- | --- | --- |
| DB-001 | `ResultSet` 在 try-finally 中保证 `close()` | High |
| DB-002 | 多步写操作放在事务（`beginTransaction` / `commit` / `rollback`） | High |
| DB-003 | 敏感数据使用加密 `RdbStore`（`encrypt: true`） | High |
| DB-004 | Preferences 写入后调 `flush()` 确保持久化 | Medium |
| DB-005 | 选型合理：KV→Preferences；结构化→Rdb；跨设备→Distributed | Low |
| DB-006 | 表结构变更走 schema migration，不直接 drop+create | High |

## 6. 权限管理（PERM）

| ID | 检查项 | 严重级 |
| --- | --- | --- |
| PERM-001 | `module.json5` 中权限最小化，按需声明 | Medium |
| PERM-002 | 敏感权限运行时调用 `requestPermissionsFromUser` | Critical |
| PERM-003 | 权限被拒后有 UI 解释和重试入口 | High |
| PERM-004 | 不存在调用 system-app-only API 但应用未具备相应身份 | High |
| PERM-005 | 权限申请前先 `canIUse('SystemCapability.X')` 守护 | Medium |

## 7. 性能（PERF）

| ID | 检查项 | 严重级 |
| --- | --- | --- |
| PERF-001 | 无 `forEach + await` / `forEach + async` 反模式（用 `for-of` 或 `Promise.all`） | High |
| PERF-002 | 长列表用 `LazyForEach` + `IDataSource`，不用 `ForEach` | High |
| PERF-003 | 高频组件用 `@Reusable` 池化 | Medium |
| PERF-004 | 大数据 / 复杂计算放 TaskPool / Worker，不阻塞 UI 线程 | High |
| PERF-005 | 图片用 WebP / SVG，不用大尺寸 PNG | Medium |
| PERF-006 | 资源懒加载（`Image.objectFit + 占位 + lazy`） | Medium |
| PERF-007 | 启用 `@AnimatableExtend` 而非每帧 setState | Low |
| PERF-008 | 列表项使用 `key` 帮助 diff | Medium |

## 8. API 版本兼容（COMPAT）

| ID | 检查项 | 严重级 |
| --- | --- | --- |
| COMPAT-001 | `compileSdkVersion` ≥ `targetSdkVersion` ≥ `minSdkVersion` | High |
| COMPAT-002 | 调用 API 14+ 引入的特性时用 `canIUse` 守护，否则 minSdk 拉到对应版本 | High |
| COMPAT-003 | 无 `@Deprecated` API 调用（含 `@ohos.*` 旧命名） | Medium |
| COMPAT-004 | 多端适配：手机 / 平板 / 折叠屏 / 智慧屏断点测试 | Medium |
| COMPAT-005 | 不在 release 构建中保留 debug-only 代码（`if (env === 'debug')`） | Low |

## 9. Kit 使用规范（KIT）

| ID | 检查项 | 严重级 |
| --- | --- | --- |
| KIT-001 | Network Kit：`http.createHttp()` 用完调 `destroy()` | High |
| KIT-002 | Image Kit：解码后释放 `imageSource`（v0.5.1 前编号 KIT-003） | High |
| KIT-003 | HMS ScanKit：dual-import `@hms.core.scan.*` 而非直接 `@kit.ScanKit`（HarmonyOS 6.x 真机 default export 解析不稳） | Medium |
| KIT-004 | HMS ScanKit：`ScanType.QR_CODE` 新名（`QRCODE` 旧名已改名，解析为 undefined → BusinessError 401） | High |
| KIT-005 | 错误处理：所有 Kit Promise 都有 catch，BusinessError 显式判 code | High |
| KIT-006 | Background Tasks Kit 不滥用，遵守平台后台执行约束 | Medium |
| KIT-007 | 跨进程通信走 RPC（@kit.AbilityKit），不用文件共享 | Medium |
| KIT-008 | File Kit：流式读写大文件，不一次性 readAll（v0.5.1 前编号 KIT-002） | Medium |
| KIT-009 | Notification Kit：通知 ID 唯一，渠道注册一次（v0.5.1 前编号 KIT-004） | Medium |

## 10. 测试与质量（TEST）

| ID | 检查项 | 严重级 |
| --- | --- | --- |
| TEST-001 | 核心业务逻辑（service / utils / viewmodel 层）有 hypium 单测覆盖；全无测试时提示补齐（不阻断） | Medium |
| TEST-002 | ohosTest 用例不硬编码生产环境 endpoint / 真实用户凭据（测试与生产隔离） | High |

> 展开指南见 [`testing-quality`](../../testing-quality/SKILL.md) skill（hypium / UiTest / `aa test` / 云测工位）。

---

## 引用方式

报告中引用规则用稳定 ID，例如：

> [STATE-002 · High] `entry/src/main/ets/pages/Cart.ets:48` — `this.items.push(item)` 就地 mutation 不触发重渲染。建议改为 `this.items = [...this.items, item]`。

这样 AI 之间、人与 AI 之间能稳定交流问题位置和类别，便于跨工具复用。
