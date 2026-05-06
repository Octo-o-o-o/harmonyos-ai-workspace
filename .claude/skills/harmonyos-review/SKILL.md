---
name: harmonyos-review
description: |
  鸿蒙 ArkTS / ArkUI 代码审查 + 9 大类 60+ 规则扫描 + 优先级报告。
  **激活条件**（满足任一即激活）：
    - 用户说"review 这段鸿蒙代码" / "审一下 PR" / "审计 .ets 文件"
    - 用户问"上线前检查" / "提审前自查" / "技术债梳理"
    - 多文件 .ets 改动需要做整体性安全 / 性能 / 规范扫描
    - 引用了 SEC-* / ARKTS-* / STATE-* / PERF-* / KIT-* / AGC-RJ-* 等规则编号
  **不激活**：单纯写一个新组件（用 arkts-rules / state-management）；非鸿蒙代码 review。
---

# 鸿蒙代码审查

> 触发场景：PR review、上架前自查、技术债梳理、引入新人前的基线扫描。
>
> **不要**只看代码片段就给评分；必须按下面的清单逐项扫，然后用模板格式产出报告。

## 审查 9 类规则

每个类目对应 [`references/checklist.md`](references/checklist.md) 中的具体扫描项。

| # | 类目 | 关键扫描点 |
| --- | --- | --- |
| 1 | **安全合规** | 硬编码密钥/口令、加密算法、输入校验、`module.json5` 权限最小化 |
| 2 | **ArkTS 语法** | `any` / 解构 / 索引签名 / 对象字面量无类型 / `console.*` 而非 `hilog` |
| 3 | **状态管理** | V1/V2 装饰器是否混用、就地 mutation 是否触发重渲染、`@Observed`/`@Trace` 缺失 |
| 4 | **生命周期** | `aboutToAppear`/`aboutToDisappear` 资源释放、订阅取消、Worker 销毁 |
| 5 | **数据库 / 持久化** | `ResultSet` 关闭、事务边界、敏感数据加密、Preferences/Relational/Distributed 选型 |
| 6 | **权限管理** | 官方授权模式、用户拒绝兜底、敏感权限的运行时申请 + UI 解释 |
| 7 | **性能** | `forEach + await` 反模式、`LazyForEach` 缺失、长列表无虚拟化、build() 副作用 |
| 8 | **API 版本兼容** | `targetSdkVersion`、`canIUse('SystemCapability.X')` 守护、Deprecated API |
| 9 | **Kit 使用规范** | `@kit.*` vs `@ohos.*` 旧式、错误的 BusinessError 处理、Promise 漏 await |

## 推荐扫描顺序

```bash
# Step 1 — 全量快速过一遍（grep 模式，定位明显问题）
grep -rEn "any |unknown |\bvar |for\s*\(.*\sin\s" --include='*.ets' --include='*.ts'
grep -rEn "console\.(log|info|warn|error|debug)" --include='*.ets' | grep -v hilog
grep -rEn "forEach.*await|forEach.*async" --include='*.ets'
grep -rn "password|secret|apikey|token" --include='*.json5' --include='*.ets'
grep -rn "ohos\.permission\." entry/src/main/module.json5

# Step 2 — 状态管理深扫
grep -rEn "this\.\w+\.push\(|this\.\w+\.splice\(|this\.\w+\.sort\(" --include='*.ets'   # 就地 mutation
grep -rEn "@Component|@ComponentV2" --include='*.ets'                                     # V1/V2 混用？

# Step 3 — Hvigor 编译期校验
hvigorw codeLinter
hvigorw assembleHap -p buildMode=debug
```

## 报告产出

- **路径约定**：`docs/reviews/YYYY-MM-DD-<scope>-review.md`
- **格式模板**：见 [`references/report-template.md`](references/report-template.md)
- **必含字段**：执行摘要（按优先级计数）、详细发现（每条带 `file:line`）、修复建议（含具体改写）、整体评级 A-F

## 优先级定义

| 级别 | 含义 | 示例 |
| --- | --- | --- |
| **Critical** | 阻断上架 / 安全漏洞 / 数据丢失 | 硬编码生产密钥；明文存储口令；敏感权限未申请就调用 |
| **High** | 影响功能可靠性，必须发版前修 | 状态管理失同步；ResultSet 泄漏；Worker 未销毁 |
| **Medium** | 技术债，下个迭代修 | `console.*` 替 `hilog`；魔数；非 Kit 化 import |
| **Low** | 锦上添花 | 注释完善；命名一致；冗余空行 |

## 整体评级标准

| 级别 | 含义 |
| --- | --- |
| **A** | 0 Critical + 0 High，Medium ≤ 5 |
| **B** | 0 Critical + High ≤ 3 |
| **C** | 0 Critical + High ≤ 8 |
| **D** | Critical ≤ 1 + High ≤ 12 |
| **F** | Critical > 1 或综合阻断上架 |

## 进一步参考

- 完整 checklist：[`references/checklist.md`](references/checklist.md)
- 官方规范汇总：[`references/official-docs.md`](references/official-docs.md)
- 报告模板：[`references/report-template.md`](references/report-template.md)
- 上架审核细则：`07-publishing/README.md`
