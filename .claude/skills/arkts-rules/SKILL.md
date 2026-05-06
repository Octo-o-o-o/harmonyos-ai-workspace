---
name: arkts-rules
description: |
  HarmonyOS / ArkTS 严格语法规则。
  **激活条件**（满足任一即激活）：
    - 用户在写 / 改 .ets 或 .ts 文件，且文件路径含 entry/ / .arkui / harmonyos / ohos
    - 用户在迁移 TypeScript 代码到 ArkTS
    - 用户问 arkts-no-* 编译错误
    - 用户提到 @kit.* / @ohos.* / Stage 模型 / ArkUI 装饰器
  **不激活**：纯 TypeScript / 浏览器 / Node.js 项目（即使语法相似）；React / Vue / 小程序代码。
---

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
