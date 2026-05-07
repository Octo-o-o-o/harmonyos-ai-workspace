# Test Fixtures

故意写错的 `.ets` / `.json5` 文件 + 1 个应该通过的样本，用于钩子和扫描脚本的回归测试。

> ⚠️ **不要把这里 `Bad*` 文件当做参考样例**——它们是反例。正确写法见 [`samples/templates/`](../../../samples/templates/) 或 [`.claude/skills/`](../../../.claude/skills/)。

## 文件清单

| 文件 | 期望 | 主要触发的规则 |
| --- | --- | --- |
| `BadState.ets` | exit=2 | STATE-002（数组就地 mutation）+ STATE-008（build 内副作用）+ ARKTS-012（console.log） |
| `BadArkTS.ets` | exit=2 | ARKTS-001（any/var）+ 003/004/005/008/009/012/014（解构/for-in/delete/旧 import 等） |
| `BadDecorators.ets` | exit=2 | STATE-001（V1/V2 装饰器混用） |
| `BadSecurityKit.ets` | exit=2 | SEC-002（hilog `%{public}` 输出 token）+ SEC-007（弱算法）+ DB-001 + KIT-002 + AGC-RJ-014 + PERF-002 + ARKTS-AWAIT-TRY |
| `BadRuntimePitfalls.ets` | exit=2 | ARKTS-RECORD + ARKTS-AWAIT-TRY + ARKTS-DEPRECATED-PICKER + ARKTS-DEPRECATED-DECODE + ARKTS-NO-UNION-CONTENT |
| `InlineDecorators.ets` | exit=2 | v0.7 回归：同行 `@Entry @Component struct` 应被识别为 ArkUI 类，类内 push 报 STATE-002 |
| `CustomDialogState.ets` | exit=2 | v0.7 回归：`@CustomDialog struct` 应在装饰器白名单内，类内 push 报 STATE-002 |
| `ReusableState.ets` | exit=2 | v0.7 回归：`@Reusable @Component struct` 同行写法应被识别 |
| `GoodPrefStore.ets` | **exit=0** | 反测试：4 类合法代码（`preferences.delete` / Record 索引赋值 / 空 Record 字面量 / 带 scan-ignore 的资源清理 catch）应**全部 0 命中** |
| `bad-oh-package.json5` | 非 0 | OHPM-FAKE：虚构 `@ohos/lottie-player` 等不存在的包名（由 `tools/check-ohpm-deps.sh` 校验） |

## 用法

```bash
# 单个 fixture 跑扫描
bash tools/hooks/lib/scan-arkts.sh tools/hooks/test-fixtures/BadState.ets

# OHPM 假包校验
bash tools/check-ohpm-deps.sh tools/hooks/test-fixtures/bad-oh-package.json5

# 全部 9 个 .ets fixture 一次过（每个文件期望的 exit code 不一样）
for f in BadState BadArkTS BadDecorators BadSecurityKit BadRuntimePitfalls \
         InlineDecorators CustomDialogState ReusableState GoodPrefStore; do
  bash tools/hooks/lib/scan-arkts.sh "tools/hooks/test-fixtures/${f}.ets" >/dev/null 2>&1
  rc=$?
  case "$f" in
    GoodPrefStore) expect=0 ;;
    *)             expect=2 ;;
  esac
  [[ "$rc" == "$expect" ]] && echo "  $f: OK" || echo "  $f: FAIL exit=$rc expect=$expect"
done
```

## 加新 fixture 的规则

每加一个反模式：

1. 写一个最小复现 `.ets` 文件，文件名前缀 `Bad`（应触发 = exit=2）或 `Good`（应通过 = exit=0）
2. 在 `tools/hooks/lib/scan-arkts.sh` 的规则集中加对应正则与 `emit_high` / `emit_med`
3. 把新 fixture 加进上面的"文件清单"表，注明期望 exit + 触发的稳定 ID
4. 把上面的"全部 9 个"循环改成"全部 N 个"+ 跑一遍全绿

不让回归通过的 PR 不合并。
