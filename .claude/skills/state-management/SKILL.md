---
name: state-management
verified_against: harmonyos-6.0.2-api22  # last sync 2026-05-07
description: |
  ArkUI V1 / V2 状态管理装饰器选型 + "数据变了 UI 不刷新" 诊断。
  **激活条件**（满足任一即激活）：
    - 代码中出现 @State / @Local / @Prop / @Param / @Link / @Provide / @Consume / @Observed / @ObservedV2 / @ObjectLink / @Trace / @Watch / @Monitor / @Computed / @Provider / @Consumer
    - 用户报告 UI 不刷新 / 状态没生效 / 数据改了视图没动 / push/splice 后列表没更新
    - 用户问 V1 vs V2 / @ComponentV2 / `$$x` 双向绑定
  **不激活**：React/Vue/Svelte 状态问题（即使关键词相似）；非 ArkUI 的 MVVM 讨论。
---

# ArkUI 状态管理

> 触发场景：用户在写或改带状态装饰器的 ArkUI 组件、调试"UI 不刷新"、或要在 V1/V2 之间选型。

## 第一铁律：替换引用，不要就地 mutation

> ArkEval 基准统计：LLM 在 ArkTS 上的错误中 **42% 是 UI 状态失同步**——压倒性的第一类 bug 来源。

ArkUI 状态系统**只追踪引用替换**，不监听对象内部修改。下面四类操作不会触发重渲染：

```typescript
// ❌ 数组：就地 push / pop / splice / sort / reverse
this.list.push(x);
this.list.splice(0, 1);

// ❌ 对象：就地修改字段（除非该类被 @Observed/@ObservedV2 修饰）
this.user.name = 'Alice';

// ❌ Map/Set：调用 set / delete / clear（外层若是 @State 仍需替换）
this.cache.set('k', v);

// ❌ 嵌套对象的深层字段（外层 @Observed 但深层未追踪）
this.profile.address.city = 'Beijing';
```

正确写法：

```typescript
// ✅ 替换引用
this.list = [...this.list, x];
this.list = this.list.filter(i => i.id !== id);
this.user = { ...this.user, name: 'Alice' };

const next = new Map(this.cache);
next.set('k', v);
this.cache = next;
```

**自检问题**：写完任何状态变更后，问"我刚才有没有重新赋值 `@State`/`@Local` 字段的引用？"——没有就一定不会刷新。

## 第二铁律：V1 / V2 不混用

一个 `.ets` 文件里要么全 V1 要么全 V2。**新项目默认 V1**（生态成熟），明确要求或需要类型严格才上 V2。

| 场景 | V1 | V2（API 12+） |
| --- | --- | --- |
| 组件 | `@Component` | `@ComponentV2` |
| 私有状态 | `@State` | `@Local` |
| 父→子单向 | `@Prop`（深拷贝可改） | `@Param`（不可变；要可变改 `@Local`） |
| 父↔子双向 | `@Link`，调用方传 `$$x` | 不直接对应；用 `@Param` + `@Event` |
| 仅初始化一次 | — | `@Once @Param` |
| 子→父事件 | 自定义函数 prop | `@Event`（必须给默认值 `() => {}`） |
| 跨层级 | `@Provide` / `@Consume` | `@Provider()` / `@Consumer()` |
| 引用对象响应 | `@Observed` 类 + `@ObjectLink` | `@ObservedV2` 类 + `@Trace` 字段 |
| 监听 | `@Watch('cb')` | `@Monitor('path')` |
| 派生计算 | 手写 getter | `@Computed get x()` |
| 全局存储 | `AppStorage` + `@StorageProp/@StorageLink` | 同 V1（未弃用） |

## 引用对象响应的两种模式

V1 类粒度（任意字段变都通知）：

```typescript
@Observed class User { name: string = ''; age: number = 0; }

@Component struct Card {
  @ObjectLink user: User;
  build() { Text(this.user.name) }
}
```

V2 字段粒度（只追踪 `@Trace` 字段，性能更好）：

```typescript
@ObservedV2 class User {
  @Trace name: string = '';   // 变了会刷
  age: number = 0;            // 变了不刷
}
```

## V1 → V2 关键差异

V1 的 `@Link` 用 `$$` 传引用：

```typescript
Toggle({ on: $$this.darkMode })   // ✅ 双向
Toggle({ on: this.darkMode })     // ❌ 单向，子改不到父
```

V2 没有 `@Link`，要双向用 `@Param` + `@Event` 一对：

```typescript
@ComponentV2 struct Child {
  @Param value: number = 0;
  @Event onValueChange: (v: number) => void = () => {};   // ⚠️ 必须默认值
  build() {
    Button('+1').onClick(() => { this.onValueChange(this.value + 1) });
  }
}
```

## V2 完整范例（鸿蒙 6 推荐风格）

V2 在 API 12+ 推出、API 21/22 已成熟。下面是覆盖 V2 全部 11 装饰器的完整范例：

### 范例 1 · `@Local` + `@Param` + `@Event`：基础双向数据流

```typescript
import { hilog } from '@kit.PerformanceAnalysisKit';

@ComponentV2
struct Counter {
  @Param @Require value: number = 0;          // ⚠️ 父 → 子，不可变；@Require 强制父必传
  @Event onValueChange: (v: number) => void = () => {};   // 子 → 父，必须默认值

  build() {
    Row() {
      Button('-').onClick(() => this.onValueChange(this.value - 1));
      Text(`${this.value}`).margin(8);
      Button('+').onClick(() => this.onValueChange(this.value + 1));
    }
  }
}

@Entry
@ComponentV2
struct Page {
  @Local count: number = 0;                   // 私有状态（替代 V1 @State）

  build() {
    Counter({
      value: this.count,
      onValueChange: (v: number) => { this.count = v }
    })
  }
}
```

### 范例 2 · `@ObservedV2` + `@Trace`：响应式对象（字段粒度）

```typescript
@ObservedV2
class User {
  @Trace name: string = '';        // 改了会触发 UI 刷新
  @Trace age: number = 0;
  email: string = '';              // 没加 @Trace → 改了不刷
}

@ComponentV2
struct UserCard {
  @Param @Require user: User = new User();
  build() {
    Column() {
      Text(this.user.name);
      Text(`${this.user.age}`);
      Text(this.user.email);     // 改 email 不会刷新
    }
  }
}
```

> **vs V1 `@Observed`**：V1 是类粒度（任意字段变都通知，性能不好）；V2 `@Trace` 是字段粒度，只追踪标了的字段。

### 范例 3 · `@Provider` / `@Consumer`：跨层级数据流

```typescript
@ComponentV2
struct App {
  @Provider() theme: 'light' | 'dark' = 'light';   // ⚠️ 注解带 ()
  build() { DeepNested() }
}

@ComponentV2
struct DeepNested {
  build() { Inner() }
}

@ComponentV2
struct Inner {
  @Consumer() theme: 'light' | 'dark' = 'light';   // 自动从最近的 Provider 拿
  build() {
    Text(this.theme === 'dark' ? '🌙' : '☀️')
  }
}
```

### 范例 4 · `@Once @Param`：父变化后子只同步一次

```typescript
@ComponentV2
struct Snapshot {
  @Once @Param value: number = 0;     // 第一次拿到后，父再变也不更新
  build() { Text(`快照值: ${this.value}`) }
}
```

### 范例 5 · `@Monitor`：精确监听字段路径变化

```typescript
@ObservedV2
class Form {
  @Trace name: string = '';
  @Trace email: string = '';

  @Monitor('name', 'email')
  validate(monitor: IMonitor): void {
    monitor.dirty.forEach(path => {
      hilog.info(0xBEEF, 'form', '%{public}s changed', path);
    });
  }
}
```

### 范例 6 · `@Computed`：派生值（带依赖追踪 + 自动缓存）

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
      Text(`合计: ${this.total}`);
      Button('+5').onClick(() => {
        this.items = [...this.items, 5];   // 必须替换引用，@Computed 才会重算
      });
    }
  }
}
```

## V1 → V2 迁移决策树

```
新建 .ets 文件，要写状态？
├── 团队 / 老项目已用 V1 ───────→ 沿用 V1（兼容性）
├── 这个文件需要派生计算 / 字段级精确追踪 ──→ V2
├── 跨层级数据流复杂 ───────────→ V2（Provider/Consumer 类型更安全）
├── targetSDK >= 21 且新业务 ──→ V2（鸿蒙 6 推荐）
└── 其他 ─────────────────────→ V1（生态最成熟）
```

## V2 反模式 Top 5

```typescript
// ❌ 1. @Param 直接被子组件改写
@Param x: number = 0;
build() { Button('').onClick(() => { this.x++ }) }   // 编译报错

// ❌ 2. @Event 没给默认值
@Event onTap: () => void;                            // 编译报错；要 = () => {}

// ❌ 3. @Provider 忘了带 ()
@Provider theme: string = 'light';                   // 错；应为 @Provider()

// ❌ 4. @Computed 依赖非响应式字段
@Local n: number = 0;
private otherN: number = 0;                          // 不响应式
@Computed get x() { return this.otherN * 2 }        // 永远不重算

// ❌ 5. @Trace 字段在普通类上（没 @ObservedV2）
class User { @Trace name: string = ''; }             // @Trace 失效；类必须 @ObservedV2
```

## 错误诊断速查

| 现象 | 大概率原因 | 解决 |
| --- | --- | --- |
| 数据变了 UI 不刷 | 就地 mutation | 替换引用 |
| 引用对象字段改了不刷 | 没加 @Observed / @ObjectLink | V1 加注解；V2 用 @ObservedV2 + @Trace |
| 列表项无限重渲染 | @Watch 回调里又改触发字段 | 加守卫或换 @Monitor |
| @Computed 不更新 | 依赖字段没用响应式装饰器 | 让依赖也是 @Local / @Trace |
| V2 子组件改 @Param 报错 | 改了不可变 prop | 用 @Local 接，再 @Event 同步父 |
| `Toggle({on: this.x})` 子改不到父 | 忘了 `$$` | `Toggle({on: $$this.x})` |
| 切换 V1/V2 后大量编译错 | 装饰器混用 | 整文件统一一种 |

## build() 的纯函数约定

```typescript
build() {
  this.fetch();         // ❌ 不要在 build() 里执行副作用
  await something();    // ❌ 不要 await
  Text('')
}
```

副作用放在 `aboutToAppear()` / `onPageShow()` / `onClick(...)` 等回调里。

## 进一步参考

- 完整模板：`01-language-arkts/03-state-management-cheatsheet.md`
- V1 文档：`upstream-docs/.../ui/state-management/arkts-state-management-overview.md`
- V2 文档：`upstream-docs/.../ui/state-management/arkts-new-state-management.md`
- 实战 case study：[`docs/case-studies/llm-chat-app.md`](../../../docs/case-studies/llm-chat-app.md) —— 真实 LLM 对话 app 的状态管理踩坑（数组就地 mutation / @Trace 字段漏标 / Map 替换引用等）
