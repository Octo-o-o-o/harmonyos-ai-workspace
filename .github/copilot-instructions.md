# HarmonyOS / ArkTS / ArkUI 开发规则（GitHub Copilot 版）

> 平台：HarmonyOS 6 系列（API 21 / 22 现行稳定线，6.1 dev beta），ArkTS + ArkUI 声明式。
> 训练数据缺失提醒：你（AI）默认会写出 TypeScript 风格但 ArkTS 编译器拒绝的代码。**先读完本文再写代码**。

## 一、ArkTS 严格语法（来源：.claude/skills/arkts-rules/SKILL.md）


# ArkTS 严格规则

> 触发场景：用户要写或改 `.ets` / `.ts` 鸿蒙文件、迁移 TypeScript 代码、或编译报 `arkts-no-*`。

## 核心心智模型

**ArkTS = TypeScript 的 AOT-friendly 严格子集 + ArkUI 装饰器扩展。**
所有"运行时不可静态分析"的特性都被禁用，因为 ArkCompiler 要做 AOT 编译。**先声明，后使用**是唯一心智模型。

## 必须遵守的硬约束

### 类型系统

```
❌ any / unknown / var
❌ 对象字面量没有先声明 class/interface
❌ obj['key'] 动态索引（除非 obj 是 Map/Record）
❌ 索引签名 [k:string]: T
❌ 结构性类型（class A 和 class B 字段相同也不互通）
❌ 交叉类型 A & B / 条件类型 / 类表达式 / Symbol
```

### 语法

```
❌ 解构赋值 const {a,b} = obj
❌ function 表达式（用箭头函数）
❌ 私有字段 # 前缀（用 private 关键字）
❌ /regex/ 字面量（用 new RegExp）
❌ delete 操作符（设 null）
❌ 一元 + 转字符串（用 Number() / parseInt）
❌ for...in（用 for-of 或普通 for）
❌ 类字段未初始化（声明时或 constructor 必须赋值）
```

### 模块

```
✅ import { http } from '@kit.NetworkKit';        ← Kit 化路径，HarmonyOS 5+ 推荐
⚠️ import http from '@ohos.net.http';             ← 旧式，仍可编译
❌ npm 包：axios / lodash / moment 等              ← 鸿蒙生态不存在，用 OHPM 包替代
```

## 改写常见 TS 反模式

| TypeScript 写法 | ArkTS 改写 |
| --- | --- |
| `const o = { a: 1, b: 2 }` | 先 `class O { a: number = 0; b: number = 0; }` 再 `const o: O = { a: 1, b: 2 }` |
| `Record<string, any>` | `Map<string, T>`，T 为具体类型 |
| `obj['key']` | 改用 `obj.key`（点访问类字段）或 `map.get('key')` |
| `const {a, b} = obj` | `const a = obj.a; const b = obj.b;` |
| `function f() {}` | `const f = (): void => {}` |
| `+'1'` | `Number('1')` 或 `parseInt('1', 10)` |
| `/foo/g` | `new RegExp('foo', 'g')` |
| `for (const k in o)` | `for (const k of Object.keys(o))` |
| `delete o.x` | `o.x = null;`（字段类型需含 null） |

## 验证流程（写完代码必跑）

```bash
ohpm install                            # 改了 oh-package.json5 才需要
hvigorw codeLinter                      # ArkTS 规则强校验
hvigorw assembleHap -p buildMode=debug  # 真编译验证
```

任何 `arkts-no-*` 错误码：在 `01-language-arkts/02-typescript-to-arkts-migration.md` 搜该编号。

## 当不确定 API 形态

**不要凭训练数据写**。ArkTS / ArkUI / Kit API 在 API 12 → 14 → 18 → 20 → 21 → 22 多次变化。

1. 先在 `upstream-docs/openharmony-docs/zh-cn/application-dev/reference/` 搜对应 Kit
2. 找不到再上 [developer.huawei.com](https://developer.huawei.com/consumer/cn/)
3. 仍不确定就告诉用户「我无法验证此 API 当前形态，建议你在 IDE 里 Ctrl+点进类型定义确认」

## 进一步参考

- 完整对照：`01-language-arkts/01-arkts-vs-typescript.md`
- 全部规则编号：`01-language-arkts/02-typescript-to-arkts-migration.md`
- 上游：`upstream-docs/.../quick-start/arkts-migration-background.md`

## 二、ArkUI 状态管理（来源：.claude/skills/state-management/SKILL.md）


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

## 三、构建与调试（来源：.claude/skills/build-debug/SKILL.md，按需展开）

改完代码必跑：

```bash
ohpm install
hvigorw codeLinter                               # 或 bash tools/run-linter.sh
hvigorw assembleHap -p buildMode=debug
```

完整 hdc / 错误码 / 三种产物速查见上面提到的 SKILL.md。

## 四、签名与上架（来源：.claude/skills/signing-publish/SKILL.md，按需展开）

签名三件套：`.p12` 私钥、`.cer` 证书、`.p7b` Profile。**调试与发布两套绝不混用**。
中国市场提审 Top 20 拒因：见 `07-publishing/checklist-2026-rejection-top20.md`。

## 五、AGENTS.md 跨工具简版（来源：AGENTS.md）

# AGENTS.md · 给 Codex / 其他 AI Agent 的指引

---
> 此文件由 `tools/generate-ai-configs.sh` 从 `.claude/skills/*/SKILL.md` 自动生成。**请勿手动编辑**——改源文件后重跑脚本。
