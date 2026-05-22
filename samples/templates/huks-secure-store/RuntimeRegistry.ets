// RuntimeRegistry.ets
// 跨模块共享 UIAbilityContext 的极简 module-singleton。
//
// 为什么需要：HarmonyOS 6+ 的 AppStorage 不接受 Context 类型
// （存进去会触发 varValueCheckFailed）。SecureStore 又需要 context
// 才能 preferences.getPreferences(ctx, name)。故走 module 级单例。
//
// 使用：
//   - EntryAbility.onCreate 调 setUIAbilityContext(this.context)
//   - SecureStore / 其他模块通过 getUIAbilityContext() 取
//
// 注意：测试 / 多 ability 场景需要谨慎；这是单 UIAbility 应用的最简方案。

import { common } from '@kit.AbilityKit'

let _ctx: common.UIAbilityContext | null = null

export function setUIAbilityContext(ctx: common.UIAbilityContext): void {
  _ctx = ctx
}

export function getUIAbilityContext(): common.UIAbilityContext | null {
  return _ctx
}
