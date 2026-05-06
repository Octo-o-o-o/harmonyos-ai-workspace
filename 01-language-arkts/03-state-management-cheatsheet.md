# ArkUI 状态管理速查 · V1 vs V2

> **铁律**：一个 `.ets` 文件**绝不混用** V1 与 V2 装饰器。
>
> **新项目默认建议**：V1（生态更成熟、教程文档量大、跨 API 兼容广）。需要更严的类型推断或新组件特性时再切 V2。
>
> **统计学第一坑**：状态变更必须**替换引用**，就地 `push/splice/sort/对象字段赋值` 不会触发重渲染。详见 [`CLAUDE.md` § 0.5](../CLAUDE.md)。

---

## 1. V1 vs V2 装饰器对照

| 场景 | V1 | V2（API 12+） | 备注 |
| --- | --- | --- | --- |
| 标记组件 | `@Component` | `@ComponentV2` | V2 必须用 `struct ... { build() }` 同语法 |
| 私有状态 | `@State` | `@Local` | V2 `@Local` 不能被外部赋值，类型更严 |
| 父→子单向 | `@Prop`（深拷贝） | `@Param`（不可变） | V2 子组件不能改 `@Param`，要可变改用 `@Local` |
| 仅初始化一次 | — | `@Once @Param` | V2 专属：父变化只在第一次同步 |
| 父↔子双向 | `@Link` 调用方传 `$$x` | 不直接对应；用 `@Param` + `@Event` 回调 | V2 强制单向数据流 |
| 子→父事件 | 自定义函数 prop | `@Event` | V2 标准化 |
| 跨层级 provide/consume | `@Provide` / `@Consume` | `@Provider()` / `@Consumer()` | V2 的注解需要 `()` |
| 引用对象响应 | `@Observed` 类 + `@ObjectLink` | `@ObservedV2` 类 + `@Trace` 字段 | V2 字段级精确追踪，性能更好 |
| 数组/Map 内字段响应 | `@Observed` 类成员 + `@ObjectLink` | `@Trace` 字段 | 同上 |
| 监听变化执行回调 | `@Watch('cb')` | `@Monitor('path.to.field')` | V2 支持深度路径 |
| 派生计算 | 手动写 getter | `@Computed get x()` | V2 自动缓存依赖 |
| 应用级存储 | `AppStorage` + `@StorageProp` / `@StorageLink` | 同 V1（**未弃用**） | 跨 V1/V2 共用 |
| 页面级存储 | `LocalStorage` + `@LocalStorageProp` / `@LocalStorageLink` | 同 V1 | 跨 V1/V2 共用 |
| 持久化 | `PersistentStorage.persistProp(...)` | 同 V1 | 跨 V1/V2 共用 |

---

## 2. V1 完整模板

### 2.1 私有状态（`@State`）

```typescript
@Entry
@Component
struct Counter {
  @State count: number = 0;

  build() {
    Column() {
      Text(`${this.count}`).fontSize(40);
      Button('+1').onClick(() => {
        this.count = this.count + 1;   // ✅ 替换引用
      });
    }
  }
}
```

### 2.2 父→子单向（`@Prop`）

```typescript
@Component
struct Child {
  @Prop label: string = '';   // 父变化会下发；子改了不影响父
  build() { Text(this.label) }
}

@Entry
@Component
struct Parent {
  @State title: string = 'Hello';
  build() {
    Column() {
      Child({ label: this.title })
    }
  }
}
```

### 2.3 父↔子双向（`@Link`）

```typescript
@Component
struct Toggle {
  @Link on: boolean;          // 子改了，父跟着变
  build() {
    Toggle({ type: ToggleType.Switch, isOn: this.on })
      .onChange(v => { this.on = v });
  }
}

@Entry
@Component
struct Settings {
  @State darkMode: boolean = false;
  build() {
    Toggle({ on: $$this.darkMode });   // ⚠️ 必须用 $$ 传引用
  }
}
```

### 2.4 跨层级（`@Provide` / `@Consume`）

```typescript
@Entry
@Component
struct App {
  @Provide('theme') theme: string = 'light';
  build() { Stack() { ChildA() } }
}

@Component
struct ChildA { build() { ChildB() } }

@Component
struct ChildB {
  @Consume('theme') theme: string;
  build() { Text(`current: ${this.theme}`) }
}
```

### 2.5 引用对象响应（`@Observed` + `@ObjectLink`）

```typescript
// ⚠️ 类必须加 @Observed，子组件用 @ObjectLink 接收
@Observed
class User {
  name: string = '';
  age: number = 0;
}

@Component
struct UserCard {
  @ObjectLink user: User;     // 接收到的 User 实例的字段变化会重渲染
  build() {
    Text(`${this.user.name}, ${this.user.age}`);
  }
}

@Entry
@Component
struct Page {
  @State u: User = new User();
  build() {
    Column() {
      UserCard({ user: this.u });
      Button('rename').onClick(() => {
        // ⚠️ 直接改字段，因为 User 是 @Observed
        this.u.name = 'Alice';
      });
    }
  }
}
```

> ⚠️ **数组里装 @Observed 对象**时也是同样规则：数组本体增删要 `this.list = [...this.list, x]`；数组**已有元素**字段变化才靠 `@Observed`。

### 2.6 全局共享（`AppStorage`）

```typescript
// 任意位置初始化（一般在 EntryAbility）
AppStorage.setOrCreate('userId', 'u_001');

@Component
struct Header {
  @StorageProp('userId') userId: string = '';     // 单向：AppStorage → 组件
  build() { Text(this.userId) }
}

@Component
struct Login {
  @StorageLink('userId') userId: string = '';     // 双向：组件改了，AppStorage 跟着变
  build() {
    Button('login').onClick(() => { this.userId = 'u_002' });
  }
}
```

### 2.7 持久化

```typescript
PersistentStorage.persistProp('theme', 'light');   // 启动时调一次
// 之后 AppStorage 中的 theme 自动落盘到 Preferences
```

---

## 3. V2 完整模板

> V2 装饰器需要 API 12+；`@ComponentV2` 与 `@Component` 不能在同一文件混用。

### 3.1 私有状态（`@Local`）

```typescript
@Entry
@ComponentV2
struct Counter {
  @Local count: number = 0;

  build() {
    Column() {
      Text(`${this.count}`).fontSize(40);
      Button('+1').onClick(() => { this.count++ });
    }
  }
}
```

### 3.2 父→子单向（`@Param`）

```typescript
@ComponentV2
struct Child {
  @Param @Require label: string = '';   // @Require 强制父必传
  build() { Text(this.label) }
}

@Entry
@ComponentV2
struct Parent {
  @Local title: string = 'Hello';
  build() { Child({ label: this.title }) }
}
```

### 3.3 仅初始化一次（`@Once @Param`）

```typescript
@ComponentV2
struct Snapshot {
  @Once @Param value: number = 0;       // 父再变也不更新
  build() { Text(`${this.value}`) }
}
```

### 3.4 子→父事件（`@Event`）

```typescript
@ComponentV2
struct Child {
  @Param value: number = 0;
  @Event onValueChange: (v: number) => void = () => {};   // 必须给默认值
  build() {
    Button('+1').onClick(() => { this.onValueChange(this.value + 1) });
  }
}

@Entry
@ComponentV2
struct Parent {
  @Local n: number = 0;
  build() {
    Child({
      value: this.n,
      onValueChange: (v: number) => { this.n = v }
    });
  }
}
```

### 3.5 引用对象响应（`@ObservedV2` + `@Trace`）

```typescript
@ObservedV2
class User {
  @Trace name: string = '';     // 只有 @Trace 字段会触发重渲染
  age: number = 0;              // 没加 @Trace 的字段变了不更新
}

@ComponentV2
struct UserCard {
  @Param @Require user: User = new User();
  build() { Text(this.user.name) }
}
```

> 性能优势：V1 的 `@Observed` 是类粒度的"任意字段变都通知"；V2 的 `@Trace` 是字段粒度的精确追踪。大对象用 V2 减少多余 diff。

### 3.6 跨层级（`@Provider` / `@Consumer`）

```typescript
@Entry
@ComponentV2
struct App {
  @Provider() theme: string = 'light';   // ⚠️ 注解带 ()
  build() { ChildB() }
}

@ComponentV2
struct ChildB {
  @Consumer() theme: string = 'light';
  build() { Text(this.theme) }
}
```

### 3.7 监听（`@Monitor`）

```typescript
@ObservedV2
class Form {
  @Trace name: string = '';
  @Trace age: number = 0;

  @Monitor('name', 'age')
  onChange(monitor: IMonitor) {
    monitor.dirty.forEach(path => {
      console.info(`${path} changed`);
    });
  }
}
```

### 3.8 派生计算（`@Computed`）

```typescript
@ComponentV2
struct Cart {
  @Local items: number[] = [10, 20, 30];

  @Computed
  get total(): number {
    return this.items.reduce((a, b) => a + b, 0);
  }

  build() {
    Column() {
      Text(`total: ${this.total}`);
      Button('add 5').onClick(() => {
        this.items = [...this.items, 5];   // 重赋值才触发 @Computed 重算
      });
    }
  }
}
```

---

## 4. 选择决策树

```
新建 .ets 文件，要写状态？
├─ 团队 / 老项目已用 V1 ────────→ 沿用 V1
├─ 这个文件需要派生计算 / 字段级精确追踪 / 类型严格 ──→ 用 V2
├─ 跨层级数据流复杂 ───────────→ V1 简单时；类型安全要求高时 V2
└─ 其他默认 ─────────────────→ V1（生态最成熟）
```

---

## 5. 反模式（一定不要这么写）

```typescript
// ❌ 1. 同一文件混用 V1/V2
@Component struct A {}
@ComponentV2 struct B {}      // 同文件出现两个会拒编译

// ❌ 2. 就地 mutation
this.list.push(x);
this.user.name = 'A';
this.cache.set('k', v);
this.profile.address.city = 'X';

// ❌ 3. V1 在子组件里改 @Prop
@Prop x: number = 0;
build() { Button('').onClick(() => { this.x++ }) }   // 不会通知父

// ❌ 4. V2 直接改 @Param
@Param y: number = 0;
build() { Button('').onClick(() => { this.y++ }) }   // 编译报错

// ❌ 5. V1 调用方忘了 $$
Toggle({ on: this.darkMode })          // 单向；改子组件影响不到父
Toggle({ on: $$this.darkMode })        // ✅ 双向

// ❌ 6. @Observed 但忘了 @ObjectLink 接收
@Observed class U { name = ''; }
@Component struct Card {
  @State u: U = new U();              // 用 @State 接 @Observed 类，字段变化不更新
  // 改成 @ObjectLink u: U  ↑ 才正确
}

// ❌ 7. V2 没给 @Event 默认值
@Event onTap: () => void;             // 编译报错；要 = () => {}

// ❌ 8. 在 build() 里执行副作用
build() {
  this.fetch();                       // ❌ build() 必须纯函数
  Text('')
}
// 副作用应放在 aboutToAppear() / onPageShow() / 事件回调里
```

---

## 6. 错误诊断路径

| 现象 | 大概率原因 | 解决 |
| --- | --- | --- |
| UI 不刷新但数据已变 | 就地 mutation | 替换引用：`this.x = [...this.x, …]` |
| 引用对象字段改了不刷 | 没加 `@Observed` 或没用 `@ObjectLink` | V1 加注解；V2 用 `@ObservedV2` + `@Trace` |
| 列表项无限刷新 | `@Watch` 回调里又改触发字段 | 加守卫或换 `@Monitor` |
| `@Computed` 不更新 | 依赖字段没用响应式装饰器 | 让依赖也是 `@Local` / `@Trace` |
| V2 子组件赋值报错 | 改了 `@Param` | 改用 `@Local`，并通过 `@Event` 同步回父 |
| 调 `Toggle({on: this.x})` 子改不到父 | 忘了 `$$` | `Toggle({ on: $$this.x })` |
| 切换 V1/V2 后大量编译错 | 装饰器混用 | 整个文件统一一种 |

---

## 7. 上游权威文档

- 完整 V1：`upstream-docs/openharmony-docs/zh-cn/application-dev/ui/state-management/arkts-state-management-overview.md`
- 完整 V2：`upstream-docs/.../ui/state-management/arkts-new-state-management.md`
- 性能优化：`upstream-docs/.../performance/state-management-performance-optimization.md`
