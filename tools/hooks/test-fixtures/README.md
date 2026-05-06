# Test Fixtures

故意写错的 `.ets` / `.json5` 文件，用于钩子和扫描脚本的回归测试。

> ⚠️ **不要把这里的代码当做参考样例**——它们是反例。正确写法见 [`01-language-arkts/`](../../01-language-arkts/) 与 [`.claude/skills/`](../../.claude/skills/)。

## 文件清单

| 文件 | 触发的规则 |
| --- | --- |
| `BadState.ets` | STATE-002（数组就地 mutation）、STATE-003（对象字段直改）、STATE-008（build() 里副作用） |
| `BadArkTS.ets` | ARKTS-001（any/var）、ARKTS-002（对象字面量无类型）、ARKTS-003（动态索引）、ARKTS-009（for-in）、ARKTS-012（console.log） |
| `BadDecorators.ets` | STATE-001（V1/V2 混用）、STATE-006（@Link 调用方忘了 $$）、STATE-008（build 副作用） |
| `bad-oh-package.json5` | OHPM-FAKE（虚构 `@ohos/lottie-player` 这种不存在的包名） |

## 用法

```bash
# 跑一遍扫描，应有所有规则被命中
bash tools/hooks/lib/scan-arkts.sh tools/hooks/test-fixtures/BadState.ets

# 校验 oh-package 假包
bash tools/check-ohpm-deps.sh tools/hooks/test-fixtures/bad-oh-package.json5

# 全部回归
bash tools/test-fixtures.sh
```

## 加新 fixture 的规则

每加一个反模式：

1. 写一个最小复现 `.ets` 文件，文件名前缀 `Bad`
2. 在 `tools/hooks/lib/scan-arkts.sh` 的规则集中加对应正则
3. 在 `tools/test-fixtures.sh` 加一行断言（"该文件应该命中规则 X"）
4. 跑 `bash tools/test-fixtures.sh` 全绿

不让回归测试通过的 PR 不合并。
