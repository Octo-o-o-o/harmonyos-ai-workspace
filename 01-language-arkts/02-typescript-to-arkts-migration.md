# TypeScript → ArkTS 迁移规则速查表

ArkTS 在 TS 基础上禁用了一批降低性能或破坏静态分析的特性。下表是 AI 助手最容易踩的禁用规则与正确写法。

> **AI 助手提示**：你（Claude / Codex 等）默认会写出 TS 风格代码。下面带 ❌ 的写法在 ArkTS 中**编译不过**。生成代码前先检查规则编号。

## 速查表（按出错频率排序）

### 1. `arkts-no-any` · 禁用 any / unknown

```typescript
// ❌
let res: any = fetchSomething();
function dump(x: unknown) { console.log(x); }

// ✅
let res: ResponseData = fetchSomething();
function dump(x: string) { console.log(x); }
```

### 2. `arkts-no-untyped-obj-literals` · 对象字面量必须有显式类型

```typescript
// ❌
let user = { id: 1, name: 'Alice' };
let user2: { id: number; name: string } = { id: 1, name: 'Alice' };

// ✅ 用 class（推荐）
class User {
  id: number = 0;
  name: string = '';
}
let user: User = { id: 1, name: 'Alice' };

// ✅ 或 interface
interface IUser { id: number; name: string }
let user: IUser = { id: 1, name: 'Alice' };
```

### 3. `arkts-no-props-by-index` · 禁用动态索引

```typescript
// ❌
console.log(p['name']);
const key = 'age';
console.log(obj[key]);

// ✅ 用点号
console.log(p.name);

// ✅ 动态访问改 Map
const m = new Map<string, string>();
m.set('age', '18');
console.log(m.get('age'));
```

### 4. `arkts-no-var` · 禁用 var

```typescript
// ❌
var count = 0;

// ✅
let count: number = 0;
const PI: number = 3.14;
```

### 5. `arkts-no-structural-typing` · 禁结构性类型

```typescript
// ❌
class Cat { name: string = ''; }
class Dog { name: string = ''; }
const c: Cat = new Dog();        // TS 会接受，ArkTS 拒绝

// ✅ 用接口或继承表达共性
interface Named { name: string }
class Cat implements Named { name: string = ''; }
class Dog implements Named { name: string = ''; }
const n: Named = new Dog();      // OK
```

### 6. `arkts-no-destruct-assignment` · 禁解构

```typescript
// ❌
const [a, b] = [1, 2];
const { name, age } = user;

// ✅
const arr = [1, 2];
const a = arr[0];
const b = arr[1];

const name = user.name;
const age = user.age;
```

### 7. `arkts-no-func-expressions` · 用箭头函数

```typescript
// ❌
const f = function(x: number) { return x * 2; };

// ✅
const f = (x: number): number => x * 2;
```

### 8. `arkts-no-private-identifiers` · 用 private 关键字

```typescript
// ❌
class C {
  #secret: string = '';
  log() { console.log(this.#secret); }
}

// ✅
class C {
  private secret: string = '';
  log() { console.log(this.secret); }
}
```

### 9. `arkts-no-regexp-literals` · RegExp 用构造函数

```typescript
// ❌
const re = /^[a-z]+$/i;

// ✅
const re = new RegExp('^[a-z]+$', 'i');
```

### 10. `arkts-no-indexed-signatures` · 禁索引签名

```typescript
// ❌
interface StringMap {
  [key: string]: string;
}

// ✅ 用 Map
const m = new Map<string, string>();

// 或具体字段
class StringMap {
  foo: string = '';
  bar: string = '';
}
```

### 11. `arkts-no-symbol` · 禁 Symbol

```typescript
// ❌
const id = Symbol('id');

// ✅ 用唯一字符串或显式字段
class ID {
  static readonly KEY: string = 'id';
}
```

### 12. `arkts-no-generic-lambdas` · 禁泛型箭头函数

```typescript
// ❌
const id = <T>(x: T): T => x;

// ✅ 改成具名函数
function id<T>(x: T): T { return x; }
```

### 13. `arkts-no-class-literals` · 禁类表达式

```typescript
// ❌
const Rectangle = class { area(): number { return 0; } };

// ✅
class Rectangle { area(): number { return 0; } }
```

### 14. `arkts-no-delete` · 禁 delete 操作符

```typescript
// ❌
delete obj.foo;

// ✅ 用 null
class Foo { val: string | null = ''; }
const f: Foo = { val: 'x' };
f.val = null;
```

### 15. `arkts-no-polymorphic-unops` · 一元 + - ~ 仅用于数字

```typescript
// ❌
const n = +'42';
const flag = !{};

// ✅
const n = parseInt('42');
const flag = false;          // 直接给 boolean
```

### 16. `arkts-no-for-in` · 禁 for…in

```typescript
// ❌
for (const k in obj) { console.log(k); }

// ✅
for (let i = 0; i < arr.length; i++) {
  console.log(arr[i]);
}

// ✅ Map
for (const [k, v] of map.entries()) { console.log(k, v); }
```

### 17. `arkts-no-intersection-types` · 禁交叉类型

```typescript
// ❌
type Employee = Identity & Contact;

// ✅
interface Employee extends Identity, Contact {}
```

### 18. `arkts-no-conditional-types` · 禁条件类型

```typescript
// ❌
type Wrap<T> = T extends number ? Box<T> : T;

// ✅ 改用泛型约束或重载
type Wrap<T extends number> = Box<T>;
```

### 19. 类字段必须在声明或 constructor 初始化

```typescript
// ❌
class A {
  name: string;          // Error: 未初始化
}

// ✅
class A {
  name: string = '';
}

// ✅
class B {
  name: string;
  constructor(n: string) { this.name = n; }
}
```

### 20. `arkts-no-construct-signatures` / 不能在构造器里声明字段

```typescript
// ❌（TS 简写）
class C {
  constructor(public name: string) {}
}

// ✅
class C {
  name: string;
  constructor(name: string) { this.name = name; }
}
```

### 21. 模板字符串 OK，但插值表达式必须有显式类型

```typescript
// ✅ 都允许
const greet = `hello ${user.name}`;
```

### 22. `arkts-no-spread` · 展开运算符限制

```typescript
// 部分允许，但混合类型（基础+对象）有警告

// ❌ 会报警
const a = [1, 2, 3];
const b = { ...a };

// ✅
const a: number[] = [1, 2, 3];
const b: number[] = [...a];   // 同类型展开 OK
```

### 23. `arkts-no-with` · 禁 with 语句

```typescript
// ❌
with (Math) { console.log(PI); }

// ✅
console.log(Math.PI);
```

### 24. import 路径推荐 `@kit.*` 而非 `@ohos.*`

```typescript
// ⚠️ 仍能编译但官方推荐
import http from '@ohos.net.http';

// ✅ Kit 化（HarmonyOS 5 起）
import { http } from '@kit.NetworkKit';
```

### 25. enum 数值必须显式

```typescript
// ❌
enum Status { OK, FAIL, RETRY }

// ✅
enum Status { OK = 0, FAIL = 1, RETRY = 2 }
```

## 完整规则文档

权威列表在以下两处：

- 官方 Cookbook（英）：<https://developer.huawei.com/consumer/en/doc/harmonyos-guides/typescript-to-arkts-migration-guide>
- awesome-harmonyos（中）：<https://github.com/HarmonyOS-Next/awesome-harmonyos/blob/main/Adaptation_rules_from_TypeScript_to_ArkTS.md>
- 本地：`upstream-docs/openharmony-docs/zh-cn/application-dev/quick-start/arkts-migration-background.md`

## 修复流程

1. DevEco Studio：**Code → Inspect Code** 或命令行 `hvigorw codeLinter`
2. 看到 `arkts-no-xxx` 形式的错误编号
3. 在本表搜该编号 → 复制正确写法
4. 14 条规则 IDE 支持一键自动修复（鼠标悬浮在标红行点 💡 灯泡）

## 给 AI 的提示词片段（可粘贴进 prompt 末尾）

```
本工程禁用以下 ArkTS-incompatible TS 写法（请严格遵守）：
- any / unknown / var
- 对象字面量缺类型注解
- obj['key'] 索引访问 → 用 Map<K,V> 或显式字段
- 解构赋值（包括函数参数解构）
- function 表达式 → 改箭头函数
- 私有字段 # 前缀 → 改 private
- /regex/ 字面量 → new RegExp(...)
- 索引签名 [k:string]:T → 改 Map 或具体字段
- Symbol / 类表达式 / 条件类型 / 交叉类型
- delete 操作符 → 设 null
- 一元 + 转字符串 → 用 parseInt
- for...in → 改 for 普通循环
- 类字段必须初始化或 constructor 赋值

import 风格：用 @kit.* 而非 @ohos.*
```
