# module.json5 改动

HUKS / preferences 都不需要在 `module.json5` 单独申请权限——它们走 app sandbox 默认能力。

但要在 `EntryAbility.onCreate` 注册 context：

```typescript
// entry/src/main/ets/entryability/EntryAbility.ets
import { setUIAbilityContext } from '../runtime/RuntimeRegistry'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    setUIAbilityContext(this.context)
  }

  onDestroy(): void {
    // 可选：清空引用避免 leak
  }

  // ... 其他生命周期方法
}
```

## 兼容性

- API 12+ 全部支持
- HarmonyOS 5 / 6 都 OK
- HUKS GCM 模式在所有华为 / 鸿蒙真机都有，无需考虑 fallback

## 卸载/重装行为

- HUKS key 随 app 卸载自动清理（不进系统 backup）
- `preferences` 文件也在 app sandbox，卸载即丢
- → 卸载重装后**所有 `get()` 都返回 null**——这是预期行为，业务侧应该有"首次使用"流程
