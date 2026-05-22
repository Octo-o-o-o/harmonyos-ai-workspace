// RuntimeRegistry.ets
// 跨模块共享 page-bound UIAbilityContext 的极简 module-singleton。
//
// 为什么 ScanKit 需要这个：
//   `startScanForResult(ctx, opts)` 的 ctx 必须是从 ArkUI `@Entry struct`
//   的 `getContext(this)` 拿到的 page-bound UIAbilityContext。
//   EntryAbility 在 onCreate 里能拿到的是裸 AbilityContext，传给 ScanKit
//   会以 BusinessError code 401 失败。
//
// 为什么不能用 AppStorage：
//   HarmonyOS 6+ 的 AppStorage 不接受 Context 类型（存进去会触发
//   varValueCheckFailed）。故走 module 级单例。
//
// 使用：
//   - 承载扫码入口的 `@Entry struct` 在 aboutToAppear 调
//     `setUIAbilityContext(getContext(this) as common.UIAbilityContext)`
//   - ScanPlugin / 其他需要 page-bound ctx 的模块通过 `getUIAbilityContext()` 取
//
// 注意：
//   - 这是单 UIAbility 应用的最简方案；多 ability 场景需要 keyed registry
//   - 与 huks-secure-store/RuntimeRegistry.ets 是同一份代码 —— 若同时用两个
//     recipe，**保留一份**就够（建议放到 entry/src/main/ets/runtime/）

import { common } from '@kit.AbilityKit'

let _ctx: common.UIAbilityContext | null = null

export function setUIAbilityContext(ctx: common.UIAbilityContext): void {
  _ctx = ctx
}

export function getUIAbilityContext(): common.UIAbilityContext | null {
  return _ctx
}
