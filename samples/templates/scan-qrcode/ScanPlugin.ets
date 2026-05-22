// ScanPlugin.ets — HMS ScanKit 二维码扫码最小可用骨架
//
// 三个真踩坑（AI 训练数据基本全错，下方代码已显式避坑）：
//   1. dual-import @hms.core.scan.* 而非 @kit.ScanKit（KIT-003）
//   2. ScanType.QR_CODE 新名而非 QRCODE 旧名（KIT-004）
//   3. context 来自 RuntimeRegistry 的 page-bound UIAbilityContext，
//      不是 EntryAbility 里的裸 AbilityContext（scanner 抓不到）
//
// 完整说明见同目录 README.md。

import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { getUIAbilityContext } from '../runtime/RuntimeRegistry'

const DOMAIN: number = 0xDE5C

// ScanKit API surface（dual-import 后我们把它们 cast 到这些接口）
interface ScanOptions {
  scanTypes: number[]
  enableMultiMode: boolean
  enableAlbum: boolean
}

interface ScanResult {
  originalValue?: string
}

interface ScanBarcodeApi {
  startScanForResult(ctx: common.UIAbilityContext, opts: ScanOptions): Promise<ScanResult>
}

interface ScanTypeApi {
  QR_CODE: number
}

interface ScanCoreApi {
  ScanType: ScanTypeApi
}

// Plugin 对外的标准化结果
export type ScanStatus = 'ok' | 'permission_denied' | 'cancelled' | 'unavailable' | 'failed'

export interface ScanOutcome {
  status: ScanStatus
  value: string
  canOpenSettings: boolean
}

export class ScanPlugin {
  private inflight: Promise<ScanOutcome> | null = null

  /**
   * 触发一次扫码。
   *
   * 同一时间只允许一个 scan inflight —— 二次点击 await 同一个 promise。
   * 用户主动取消 / 权限被拒 / SDK 不可用都不会 throw；只有真意外才 throw。
   */
  async scan(): Promise<ScanOutcome> {
    if (this.inflight !== null) return this.inflight
    this.inflight = this.runScan()
    try {
      return await this.inflight
    } finally {
      this.inflight = null
    }
  }

  private async runScan(): Promise<ScanOutcome> {
    // —— 坑 1：dual-import + 显式 .default ——
    let scanBarcodeMod: ESObject
    let scanCoreMod: ESObject
    try {
      scanBarcodeMod = await import('@hms.core.scan.scanBarcode')
      scanCoreMod = await import('@hms.core.scan.scanCore')
    } catch (e) {
      const err = e as BusinessError
      hilog.error(DOMAIN, 'ScanPlugin', 'hms scan modules import failed: code=%{public}d msg=%{public}s',
        err.code ?? -1, err.message ?? String(e))
      return { status: 'unavailable', value: '', canOpenSettings: false }
    }
    const scanBarcode = (scanBarcodeMod.default as ScanBarcodeApi)
    const scanCore = (scanCoreMod.default as ScanCoreApi)

    // —— 坑 3：page-bound UIAbilityContext ——
    // EntryAbility.context 是 bare AbilityContext，传给 ScanKit 会 code 401。
    // 页面 aboutToAppear 时把 getContext(this) 注册到 RuntimeRegistry，
    // plugin 从 registry 取。
    const pageCtx = getUIAbilityContext()
    if (pageCtx === null) {
      hilog.error(DOMAIN, 'ScanPlugin', 'no page-bound UIAbilityContext registered; did you call setUIAbilityContext in aboutToAppear?')
      return { status: 'unavailable', value: '', canOpenSettings: false }
    }

    // —— 坑 2：ScanType.QR_CODE 新名 ——
    const opts: ScanOptions = {
      scanTypes: [scanCore.ScanType.QR_CODE],
      enableMultiMode: false,
      enableAlbum: true,
    }

    try {
      const result: ScanResult = await scanBarcode.startScanForResult(pageCtx, opts)
      const value = (typeof result.originalValue === 'string') ? result.originalValue.trim() : ''
      return { status: 'ok', value, canOpenSettings: false }
    } catch (e) {
      const err = e as BusinessError
      const code: number = (typeof err.code === 'number') ? err.code : -1
      hilog.warn(DOMAIN, 'ScanPlugin', 'startScanForResult failed code=%{public}d msg=%{public}s',
        code, err.message ?? String(e))
      // —— 错误码到 outcome 的映射（HarmonyOS 6.x 真实码）——
      if (code === 1000500001) {
        // 相机权限被拒：HarmonyOS 没有 shouldShowRationale，永远 canOpenSettings:true
        return { status: 'permission_denied', value: '', canOpenSettings: true }
      }
      if (code === 1000500002) {
        // 用户关掉扫码 UI / 中断
        return { status: 'cancelled', value: '', canOpenSettings: false }
      }
      if (code === 401) {
        // 参数校验失败：多半是 ScanType 枚举值错 / ctx 来源错。开发期会撞，
        // 上线代码不应再出现 —— 故归 unavailable + 重 log。
        return { status: 'unavailable', value: '', canOpenSettings: false }
      }
      return { status: 'failed', value: '', canOpenSettings: false }
    }
  }
}
