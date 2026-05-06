# ArkTS vs TypeScript · 决策对照表

> ArkTS 是 TypeScript 的**严格子集**外加 UI 装饰器扩展。它的核心约束不是"少几个语法糖"，而是为了让 ArkCompiler 做 AOT 编译——所以一切**运行时不可静态分析**的特性都被禁掉。
>
> 如果你已熟悉 TypeScript，下面这张表回答了 80% 的常见疑问；剩下 20% 见 [`02-typescript-to-arkts-migration.md`](02-typescript-to-arkts-migration.md)（含每条规则的 `arkts-no-*` 编号）。

---

## 1. 类型系统差异（最频繁踩坑）

| 主题 | TypeScript | ArkTS | 一句话规则 |
| --- | --- | --- | --- |
| `any` / `unknown` | ✅ 允许 | ❌ 禁用 | 必须显式类型 |
| 对象字面量无类型 | ✅ `const o = { a: 1 }` | ❌ 必须先声明 class/interface 再字面量 | 字面量必须有"模版" |
| 索引签名 `{[k:string]:T}` | ✅ | ❌ | 用 `Map<string,T>` |
| 动态访问 `obj['key']` | ✅ | ❌ 仅当 `obj` 是 `Record`/`Map` 时合法 | 访问类字段用点语法 |
| 结构性类型 | ✅ duck typing | ❌ 名义类型 | 字段相同的两个 class 不互通 |
| 交叉类型 `A & B` | ✅ | ❌ | 用继承或合并 interface |
| 条件类型 `T extends U ? X : Y` | ✅ | ❌ | 拆成多个具名类型 |
| 类表达式 | ✅ `const A = class {}` | ❌ | 必须 `class A {}` 声明式 |
| Symbol | ✅ | ❌（仅 `Symbol.iterator` 可用） | 用枚举替代 |
| 索引返回 `T \| undefined` | TS 严格模式同 | ArkTS 同样要求显式判空 | `.find()` 返回值要 `as` 或判空 |

---

## 2. 语法层面差异

| 主题 | TypeScript | ArkTS | 替换 |
| --- | --- | --- | --- |
| `var` | ✅（不推荐） | ❌ | `let` / `const` |
| 解构赋值 `const {a,b} = obj` | ✅ | ❌ | 一行一行赋值 |
| 解构入参 `f({a, b})` | ✅ | ❌ | 传整对象再字段访问 |
| 数组解构 `const [a,b] = arr` | ✅ | ⚠️ 有限支持，建议避免 | 用 `arr[0]` |
| `function` 表达式 | ✅ `const f = function(){}` | ❌ | 箭头函数 `const f = () => {}` |
| `function` 声明嵌套 | ✅ | ⚠️ 顶层 OK，内嵌建议改箭头 | 同上 |
| 私有字段 `#priv` | ✅ ES 标准 | ❌ | `private priv` 关键字 |
| 字段在 constructor 内首声明 | ✅ | ❌ | 类体内先声明并初始化 |
| 类字段未初始化 | ✅（TS strict 才报） | ❌ 强制 | 必须给默认值或 constructor 内赋 |
| `delete obj.key` | ✅ | ❌ | 设 null / 重建对象 |
| 一元 `+` 转数字 `+'1'` | ✅ | ❌ | `Number('1')` / `parseInt('1', 10)` |
| 正则字面量 `/x/g` | ✅ | ❌ | `new RegExp('x', 'g')` |
| `for...in` | ✅ | ❌ | `for (const k of Object.keys(o))` 或普通 `for` |
| `for...of` 迭代字符串 | ✅ | ✅ | 同 |
| 模板字符串 | ✅ | ✅ | 同 |
| 可选链 `a?.b` / 空合并 `a??b` | ✅ | ✅ | 同 |
| 展开 `...arr` | ✅ | ✅ | 同 |

---

## 3. 模块系统差异

| 主题 | TypeScript | ArkTS |
| --- | --- | --- |
| ES Module `import/export` | ✅ | ✅ |
| CommonJS `require` | ⚠️ 旧代码 | ❌ |
| 默认导出 `export default` | ✅ | ✅ 但 ArkUI 组件文件**不要**用 default |
| 命名空间 `namespace` | ✅ | ⚠️ 仅在 `.d.ts` 中 |
| 路径别名 | tsconfig.paths | `oh-package.json5` 的 `dependencies` |
| npm 包 | ✅ | ❌ 必须 OHPM (`.har`/`.hsp`) |
| `@ohos.*` | — | ⚠️ 旧式仍可用 |
| `@kit.*` | — | ✅ 推荐（Kit 化路径，HarmonyOS 5+） |

```typescript
// ✅ 推荐 import 风格
import { http } from '@kit.NetworkKit';
import { window } from '@kit.ArkUI';
import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
```

---

## 4. 错误处理差异

| 主题 | TypeScript | ArkTS |
| --- | --- | --- |
| `try/catch/finally` | ✅ | ✅ |
| `catch` 参数类型 | `unknown` (TS 4.4+) | `Error` 或 `BusinessError` 实例 |
| `BusinessError` | — | ✅ Kit API 抛出的标准错误类型 |

```typescript
import { BusinessError } from '@kit.BasicServicesKit';

try {
  // call kit api
} catch (e) {
  const err = e as BusinessError;
  console.error(`code=${err.code}, msg=${err.message}`);
}
```

---

## 5. 异步与并发差异

| 主题 | TypeScript | ArkTS |
| --- | --- | --- |
| `Promise` / `async/await` | ✅ | ✅ |
| `setTimeout` / `setInterval` | ✅ | ✅ |
| Web Worker | ⚠️ 浏览器 | ✅ 用 `@kit.ArkTS` 的 Worker |
| 后台任务池 | — | ✅ `taskpool`（推荐，自动调度） |
| `@Concurrent` 装饰器 | — | ✅ 标记可在 Worker 跑的纯函数 |
| 跨线程共享内存 | — | `SendableXxx` 系列容器 |

```typescript
import { taskpool } from '@kit.ArkTS';

@Concurrent
function heavy(n: number): number {
  let s = 0;
  for (let i = 0; i < n; i++) s += i;
  return s;
}

const r = await taskpool.execute(heavy, 1_000_000) as number;
```

---

## 6. UI 装饰器（TypeScript 中不存在）

ArkUI 是 ArkTS 的"杀手级"扩展。TypeScript 完全没有这一层：

```typescript
@Entry           // 页面入口（每页 1 个）
@Component       // V1 组件
@ComponentV2     // V2 组件（API 12+，二选一不混用）
@State           // V1 私有状态
@Local           // V2 私有状态
@Prop / @Param   // 父→子（V1 / V2）
@Link            // V1 父↔子双向，调用方传 $$x
@Event           // V2 子→父事件
@Provide / @Consume     // V1 跨层级
@Provider() / @Consumer()   // V2 跨层级
@Observed / @ObjectLink     // V1 引用对象响应
@ObservedV2 / @Trace         // V2 引用对象响应
@Watch / @Monitor            // 监听变化
@Computed                    // V2 派生计算
@Builder / @BuilderParam     // 复用 UI 块
@Styles / @Extend            // 复用样式
@Reusable                    // 组件池化
@Preview                     // IDE 预览
@AnimatableExtend            // 动画扩展属性
```

完整状态管理对照见 [`03-state-management-cheatsheet.md`](03-state-management-cheatsheet.md)。

---

## 7. tsconfig vs ArkTS 配置

ArkTS 没有 `tsconfig.json`。配置散落在三处：

| 配置项 | TypeScript | ArkTS |
| --- | --- | --- |
| 编译器选项 | `tsconfig.json` | `build-profile.json5` 的 `arkOptions` |
| 严格类型 | `"strict": true` | 自动开启，无开关 |
| 路径映射 | `compilerOptions.paths` | `oh-package.json5` `dependencies` |
| 代码风格规则 | ESLint / Prettier | `code-linter.json5` + `hvigorw codeLinter` |
| 混淆 | terser/uglify | `obfuscation-rules.txt` + `arkOptions.obfuscation` |

---

## 8. 一段「TS 写法 → ArkTS 写法」迁移示例

**原 TypeScript：**

```typescript
// fetcher.ts
async function fetchUser(id: number) {
  const r = await fetch(`/api/users/${id}`);
  const j = await r.json();
  return { id: j['id'], name: j['name'] };
}

const cache: Record<string, any> = {};
cache['k1'] = await fetchUser(1);
```

**改写 ArkTS：**

```typescript
// fetcher.ts
import { http } from '@kit.NetworkKit';

class User {
  id: number = 0;
  name: string = '';
}

async function fetchUser(id: number): Promise<User> {
  const req = http.createHttp();
  const resp = await req.request(`https://api.example.com/users/${id}`);
  const j: User = JSON.parse(resp.result as string);
  const u = new User();
  u.id = j.id;
  u.name = j.name;
  return u;
}

const cache: Map<string, User> = new Map();
cache.set('k1', await fetchUser(1));
```

修了什么：
- `fetch` → `@kit.NetworkKit` 的 `http`
- 字面量 `{ id, name }` → 显式 class `User`
- `Record<string, any>` → `Map<string, User>`
- `cache['k1'] =` → `cache.set('k1', …)`
- `j['id']` → `j.id`（先 cast 成已声明 class）

---

## 9. 何时该「投降」？

如果你写出的代码 ArkTS 编译器死活不通过：

1. 把错误码 `arkts-no-xxx` 在 [`02-typescript-to-arkts-migration.md`](02-typescript-to-arkts-migration.md) 搜
2. 仍找不到 → `upstream-docs/openharmony-docs/zh-cn/application-dev/quick-start/arkts-migration-background.md`
3. 还找不到 → 上 [developer.huawei.com](https://developer.huawei.com/consumer/cn/) 的 ArkTS 文档
4. 都不行 → **重写**：把那段拆成更小、类型更显式的代码。ArkTS 的设计哲学是"宁可冗长也要静态可分析"

---

## 10. 一句话总结

> **ArkTS = TypeScript 的"AOT-friendly" 子集 + ArkUI 装饰器**。
> 所有"动态"特性（`any` / 对象字面量直生 / 解构 / 索引签名 / 结构性类型）都被换成"显式"对应物。**先声明，后使用**——这是 ArkTS 的唯一心智模型。
