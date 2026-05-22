# Recipe · HMS ScanKit 二维码扫码（最小可用）

> HarmonyOS NEXT 真机稳定的二维码扫码骨架：dual-import + page-bound `UIAbilityContext` + 错误码到业务 outcome 的标准映射。
>
> **真实出处**：OctoDesk Mobile 的 `DesktopRemoteQrScanner.ets` 简化版。
>
> verified_against: harmonyos-6.0.2-api22

## 什么时候用

- 扫码加入设备 / 扫码登录 / 扫码配对
- 任何"用户主动触发的相机识别"场景（被动监听 / 后台轮询不在 ScanKit 范围）

## 什么时候**不要**用

- 自定义识别算法 / 离线条码（ScanKit 走 HMS Core 在线模块；可以离线识别但模块需在）
- 想拿到原始相机帧做后处理 → 用 `@kit.CameraKit`，不是 ScanKit

## 三个坑（AI 训练数据基本全错，重点验证）

1. **`@kit.ScanKit` 直接 import 真机不稳** —— 改 dual-import：
   ```typescript
   const sb = (await import('@hms.core.scan.scanBarcode')).default
   const sc = (await import('@hms.core.scan.scanCore')).default
   ```
   由 [`KIT-003`](../../tools/hooks/lib/scan-arkts.sh) 守门。

2. **`ScanType.QRCODE` 已改名为 `QR_CODE`** —— HarmonyOS 6.x 旧值是 `undefined`，传入 `options.scanTypes` 让 `startScanForResult` 以 BusinessError `code 401` 整体失败。由 [`KIT-004`](../../tools/hooks/lib/scan-arkts.sh) 守门。

3. **`startScanForResult(ctx, options)` 的 `ctx` 必须是 page-bound** —— 不是 EntryAbility 里那个裸 `AbilityContext`。从 `@Entry struct` 内调 `getContext(this) as common.UIAbilityContext` 取，写进 `RuntimeRegistry`，plugin 从 registry 拿。**这条 scanner 抓不到**。

## 约束（必须满足）

1. **必须申请 `ohos.permission.CAMERA`** —— 在 `module.json5` 的 `requestPermissions` 数组里。本目录的 `module.json5.patch.md` 是模板片段。
2. **runScan 必须包 try/catch** —— BusinessError 都从这里抛，没有 catch 就崩；codeLinter 也会报 ARKTS-AWAIT-TRY。
3. **错误码用 number 比较，不用 string** —— `e.code` 是 number；本 recipe 列了三个真实码。
4. **同一时间只能有一个 scan inflight** —— 用一个 `Promise<string> | null` 字段做互斥；二次点击应当 await 同一个 promise。
5. **不要把 page-bound ctx 缓存在 plugin 字段里** —— 页面卸载后 ctx 失效。每次扫描临时从 registry 取。

## 错误码到业务 outcome 映射

| BusinessError code | 含义 | 推荐 outcome |
|---|---|---|
| `1000500001` | 相机权限被拒 | `permission_denied`（HarmonyOS 没有 `shouldShowRationale`，引导用户去系统设置即可） |
| `1000500002` | 用户主动关闭扫码 UI / 中断 | `cancelled` |
| `401` | 参数校验失败（多半 ScanType 错 / ctx 错） | `unavailable`（写 hilog 含 raw error，开发期定位） |
| 其他 | 未知 | `failed` + 上报 telemetry |

## 集成步骤

1. **复制文件**：
   - `ScanPlugin.ets` → `entry/src/main/ets/scan/`
   - `RuntimeRegistry.ets` → `entry/src/main/ets/runtime/`（若已有共享 registry，复用即可，**不要建两份**）
2. **`module.json5` 加权限** —— 见 [`module.json5.patch.md`](./module.json5.patch.md)
3. **页面注册 page-bound context** —— 在承载扫码入口的 `@Entry struct` 内：

   ```typescript
   import { common } from '@kit.AbilityKit'
   import { setUIAbilityContext } from '../runtime/RuntimeRegistry'

   @Entry
   @Component
   struct Index {
     aboutToAppear(): void {
       setUIAbilityContext(getContext(this) as common.UIAbilityContext)
     }
     // ...
   }
   ```

4. **业务调用**：

   ```typescript
   import { ScanPlugin } from './scan/ScanPlugin'

   const scanner = new ScanPlugin()
   const outcome = await scanner.scan()
   // outcome.status: 'ok' | 'permission_denied' | 'cancelled' | 'unavailable' | 'failed'
   // outcome.value: 仅 status='ok' 时是扫出的字符串
   ```

5. **如果走 Web Bridge**：把 plugin attach 到 `BridgeRuntime`，业务区 invoke `qrscan` capability；handshake 的 `granted` 列表必须从 handler registry 派生（见 [`bridge-integration-pitfalls.md §1`](../../../05-best-practices/bridge-integration-pitfalls.md)）。

## 反模式（不要这么写）

```typescript
// ❌ 单点 import + 旧枚举值 + 裸 context
const scanKit: ESObject = await import('@kit.ScanKit')          // KIT-003
const opts = { scanTypes: [scanKit.scanCore.ScanType.QRCODE] }  // KIT-004
await scanKit.scanBarcode.startScanForResult(this.context, opts)  // ctx 来源错
```

```typescript
// ❌ 没 try/catch（ARKTS-AWAIT-TRY）+ 没区分 cancelled / denied
const result = await scanBarcode.startScanForResult(ctx, opts)
return result.originalValue   // ← 用户取消时 result.originalValue 是空字符串
                              //    会和"扫了一个空 QR"无法区分；要靠 catch 的 code
```

```typescript
// ❌ 把 plugin 的 ctx 字段 cache 后跨页使用
class Bad {
  private ctx = AppStorage.get<common.UIAbilityContext>('ctx')  // 6.x varValueCheckFailed
}
```

## 上 PR 前

- [ ] `bash tools/hooks/lib/scan-arkts.sh ScanPlugin.ets` exit 0
- [ ] `module.json5` 有 `ohos.permission.CAMERA` + reason 文案
- [ ] 真机过一遍：扫一个有效 QR / 取消扫描 / 拒绝相机权限 三条路径都跑通
- [ ] 错误码 → bridge outcome 的映射写进单测 fixture，未来 OS 升级新增 code 能立即发现
