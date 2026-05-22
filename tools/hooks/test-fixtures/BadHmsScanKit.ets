// Test fixture · 触发 v0.4 新增的 HMS ScanKit 规则
// 期望钩子命中：KIT-003（@kit.ScanKit 直接 import）+ KIT-004（ScanType.QRCODE 旧名）
//
// 背景：来自 OctoDesk 反哺（2026-05-22 commit 3f0c76c5）——HMS ScanKit 在
// HarmonyOS NEXT 6.x 真机上：
//   1. `@kit.ScanKit` 直接 dynamic import 时 scanBarcode/scanCore 可能为 undefined
//   2. ScanType 枚举值从 QRCODE 改名为 QR_CODE，旧值传入会让 startScanForResult
//      以 BusinessError code 401 失败
//
// 正确写法见 GoodHmsScanKit.ets 与 samples/templates/scan-qrcode/。

import { common } from '@kit.AbilityKit'

interface ScanResult {
  originalValue?: string
}

interface ScanOptions {
  scanTypes: number[]
  enableMultiMode: boolean
  enableAlbum: boolean
}

interface ScanBarcodeApi {
  startScanForResult(ctx: common.UIAbilityContext, opts: ScanOptions): Promise<ScanResult>
}

interface ScanCoreApi {
  ScanType: ScanTypeApi
}

interface ScanTypeApi {
  QRCODE: number
  QR_CODE: number
}

export class BadScanner {
  constructor(private context: common.UIAbilityContext) {}

  async run(): Promise<string> {
    // KIT-003: 单点 import @kit.ScanKit —— 真机不稳
    const scanKit: ESObject = await import('@kit.ScanKit')
    const scanBarcode = scanKit.scanBarcode as ScanBarcodeApi
    const scanCore = scanKit.scanCore as ScanCoreApi
    const opts: ScanOptions = {
      // KIT-004: ScanType.QRCODE 旧名 —— HarmonyOS 6.x undefined
      scanTypes: [scanCore.ScanType.QRCODE],
      enableMultiMode: false,
      enableAlbum: true,
    }
    const result = await scanBarcode.startScanForResult(this.context, opts)
    return result.originalValue ?? ''
  }
}
