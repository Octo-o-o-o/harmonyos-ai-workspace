# ArkTS 语言

**ArkTS** 是 HarmonyOS 的主力开发语言，基于 TypeScript 强化扩展，专为声明式 UI 与高性能场景优化。

## 1. 与 TypeScript 的关系

- ArkTS = TypeScript 子集 + UI 装饰器扩展 + 严格类型限制
- 不允许：`any`、动态属性增删、prototype 修改、对象字面量结构发散
- 性能：规则的语法让 ArkCompiler 能做 AOT 编译，启动比 Hermes / V8 快很多

详细差异：`upstream-docs/openharmony-docs/zh-cn/application-dev/quick-start/arkts-migration-background.md`

## 2. 必读官方文档（本地路径）

| 主题 | 本地路径 |
| --- | --- |
| ArkTS 入门 | `upstream-docs/openharmony-docs/zh-cn/application-dev/quick-start/arkts-get-started.md` |
| ArkTS 语言介绍 | `upstream-docs/.../quick-start/introduction-to-arkts.md` |
| 编码风格 | `upstream-docs/.../quick-start/arkts-coding-style-guide.md` |
| Java 程序员视角 | `upstream-docs/.../quick-start/getting-started-with-arkts-for-java-programmers.md` |
| Swift 程序员视角 | `upstream-docs/.../quick-start/getting-started-with-arkts-for-swift-programmers.md` |
| 高性能编程 | `upstream-docs/.../quick-start/arkts-high-performance-programming.md` |
| 完整 utils 集合 | `upstream-docs/.../arkts-utils/` |

## 3. 核心装饰器一览

### UI 相关

| 装饰器 | 用途 |
| --- | --- |
| `@Entry` | 标记页面入口组件，每页只能有一个 |
| `@Component` | 标记自定义 ArkUI 组件 |
| `@Builder` | 声明可复用的 UI 函数 |
| `@BuilderParam` | 父组件向子组件传 UI 块 |
| `@Styles` | 复用样式块 |
| `@Extend` | 给特定组件扩展样式 |
| `@CustomDialog` | 自定义对话框 |
| `@Preview` | DevEco Studio 中的实时预览 |
| `@Reusable` | 标记组件可被复用池化 |
| `@AnimatableExtend` | 自定义可动画扩展属性 |

### 状态管理（重点）

| 装饰器 | 作用域 | 方向 |
| --- | --- | --- |
| `@State` | 组件内私有 | 内部读写 |
| `@Prop` | 父→子 | 单向，子修改不影响父 |
| `@Link` | 父↔子 | 双向绑定 |
| `@Provide` / `@Consume` | 跨多层组件 | 后代任意组件订阅 |
| `@ObjectLink` / `@Observed` | 引用对象类成员变化 | 对象变化触发 UI 更新 |
| `@StorageProp` / `@StorageLink` | 全应用 AppStorage | 全局共享 |
| `@LocalStorageProp` / `@LocalStorageLink` | 页面级 LocalStorage | 页面间共享 |
| `@Watch` | 监听变量变化执行回调 | 副作用 |
| `@Track` | class 字段级精确追踪 | 减少不必要重渲染 |

### V2 状态管理（API 12+ 推荐新写法）

| 装饰器 | 等价 V1 | 改进 |
| --- | --- | --- |
| `@ComponentV2` | `@Component` | 状态系统升级 |
| `@Local` | `@State` | 类型更严，无法被外部赋值 |
| `@Param` | `@Prop` | 不可变 |
| `@Once` | — | 父更新仅一次 |
| `@Event` | — | 子→父事件 |
| `@Provider` / `@Consumer` | `@Provide` / `@Consume` | 类型安全 |
| `@ObservedV2` / `@Trace` | `@Observed` / `@Track` | 性能更好 |
| `@Monitor` | `@Watch` | 支持深度路径 |
| `@Computed` | — | 派生计算，自动缓存 |

详见 `upstream-docs/.../ui/state-management/`。

## 4. ArkTS 严格规则示例

```typescript
// ❌ 禁止：any
let x: any = 1;

// ❌ 禁止：动态扩展属性
class Foo {}
const f = new Foo();
(f as any).bar = 1;

// ❌ 禁止：对象字面量结构无声明
const obj = { a: 1, b: 2 };
obj.c = 3;          // Error

// ✅ 推荐：明确声明所有字段
class Foo2 { a: number = 0; b: number = 0; }
const obj2: Foo2 = { a: 1, b: 2 };

// ❌ 禁止：函数无返回类型时返回 union
function bar(c: boolean) {
  if (c) return 1;
  return 'x';        // Error: 类型不一致
}

// ✅ 用 union 显式声明
function bar2(c: boolean): number | string {
  return c ? 1 : 'x';
}
```

## 5. 异步与并发

- `async / await`、`Promise` 全部支持
- **TaskPool** / **Worker**：跨线程并发，UI 线程严禁阻塞
  ```typescript
  import { taskpool } from '@kit.ArkTS';

  @Concurrent
  function heavy(n: number): number {
    let sum = 0;
    for (let i = 0; i < n; i++) sum += i;
    return sum;
  }

  const result = await taskpool.execute(heavy, 1_000_000);
  ```
- 详见 `upstream-docs/.../arkts-utils/multi-thread-concurrency.md`

## 6. 模块化

- 包管理：OHPM（`oh-package.json5`）
- 三种产物：HAP（应用包）、HAR（静态库）、HSP（动态共享库）
- 路径别名：`oh-package.json5` 中配 `dependencies` `devDependencies`
- 系统模块：`@kit.*`（推荐）、`@ohos.*`（旧式）

```typescript
import { window } from '@kit.ArkUI';
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import http from '@ohos.net.http';
```

## 7. 常用片段

### 类与接口

```typescript
interface User {
  id: number;
  name: string;
  email?: string;
}

class UserService {
  private users: User[] = [];

  add(user: User): void {
    this.users.push(user);
  }

  find(id: number): User | undefined {
    return this.users.find(u => u.id === id);
  }
}
```

### 错误处理

```typescript
import { BusinessError } from '@kit.BasicServicesKit';

try {
  // ...
} catch (e) {
  const err = e as BusinessError;
  console.error(`code=${err.code}, msg=${err.message}`);
}
```

### 工厂方法 + 泛型

```typescript
class Container<T> {
  private items: Array<T> = [];

  add(item: T): void { this.items.push(item); }
  get(i: number): T | undefined { return this.items[i]; }
}
```

## 8. 进一步学习

- [`01-arkts-vs-typescript.md`](01-arkts-vs-typescript.md) — 与 TypeScript 的差异决策对照表，含完整迁移示例
- [`02-typescript-to-arkts-migration.md`](02-typescript-to-arkts-migration.md) — 每条 `arkts-no-*` 规则的解释与改写
- [`03-state-management-cheatsheet.md`](03-state-management-cheatsheet.md) — V1 vs V2 状态管理速查、反模式、错误诊断
- 上游：`upstream-docs/.../quick-start/arkts-more-cases.md`（综合范例）
