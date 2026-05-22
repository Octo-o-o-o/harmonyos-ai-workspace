// Test fixture · 反测试：HMS ScanKit 正确写法应**0 命中**
// 验证 KIT-003 / KIT-004 不会误报 dual-import + QR_CODE 形态。
//
// 同时验证：QR_CODE 字面量不会让 KIT-004 的 `\bScanType\.QRCODE\b` 误命中
// （`QR_CODE` 含 `_`，是 word 字符，QRCODE\b 不会跨越下划线）。
//
// 完整可跑骨架见 samples/templates/scan-qrcode/。

import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN: number = 0xDE5C

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

interface ScanCoreApi {
  ScanType: ScanTypeApi
}

interface ScanTypeApi {
  QR_CODE: number
}

export class GoodScanner {
  constructor(private context: common.UIAbilityContext) {}

  async run(): Promise<string> {
    try {
      // dual-import + 显式取 .default —— 真机稳定
      const scanBarcodeMod: ESObject = await import('@hms.core.scan.scanBarcode')
      const scanCoreMod: ESObject = await import('@hms.core.scan.scanCore')
      const scanBarcode = scanBarcodeMod.default as ScanBarcodeApi
      const scanCore = scanCoreMod.default as ScanCoreApi
      const opts: ScanOptions = {
        // 新名 QR_CODE —— HarmonyOS 6.x 正确值
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: true,
      }
      const result = await scanBarcode.startScanForResult(this.context, opts)
      return result.originalValue ?? ''
    } catch (e) {
      const err: ESObject = e
      hilog.error(DOMAIN, 'GoodScanner', 'scan failed code=%{public}s', String(err.code))
      return ''
    }
  }
}
