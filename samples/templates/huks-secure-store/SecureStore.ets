// SecureStore.ets
// 最小可用 HUKS 加密本地存储（OctoDesk Mobile 的简化版）
//
// 模式：
//   - 单条字符串值 → @kit.ArkData preferences 落盘
//   - 写入前用 HUKS AES-256-GCM 包装（key 在 HUKS 内不可导出）
//   - 存储格式：`ivHex|cipherHex`（带认证 tag 在 GCM mode 里随密文）
//
// ArkTS V1 约束：
//   - BusinessError 显式 catch
//   - 没有 any
//   - 异步 await，不写回调金字塔

import { preferences } from '@kit.ArkData'
import { huks } from '@kit.UniversalKeystoreKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { getUIAbilityContext } from '../runtime/RuntimeRegistry'

const PREFS_NAME: string = 'app.securestore'
const HUKS_ALIAS: string = 'app.securestore.aesKey'

// ─── 公开接口 ─────────────────────────────────────────────────

export interface SecureStore {
  get(key: string): Promise<string | null>
  set(key: string, value: string): Promise<void>
  wipe(key: string): Promise<void>
  wipeAll(): Promise<void>
}

// ─── 默认实现 ─────────────────────────────────────────────────

export class HuksWrappedPreferenceStore implements SecureStore {
  private prefsName: string

  constructor(prefsName: string = PREFS_NAME) {
    this.prefsName = prefsName
  }

  private async openPrefs(): Promise<preferences.Preferences> {
    const ctx = getUIAbilityContext()
    if (!ctx) {
      throw new Error('SecureStore: UIAbilityContext 未注册。请在 EntryAbility.onCreate 调 setUIAbilityContext')
    }
    try {
      return await preferences.getPreferences(ctx, this.prefsName)
    } catch (e) {
      const err = e as BusinessError
      throw new Error(`SecureStore.openPrefs failed: code=${err.code}`)
    }
  }

  async get(key: string): Promise<string | null> {
    try {
      const prefs = await this.openPrefs()
      const wrapped = await prefs.get(key, '') as string
      if (wrapped === '') {
        return null
      }
      return await this.unwrap(wrapped)
    } catch (e) {
      const err = e as BusinessError
      throw new Error(`SecureStore.get(${key}) failed: code=${err.code}`)
    }
  }

  async set(key: string, value: string): Promise<void> {
    try {
      await this.ensureKey()
      const wrapped = await this.wrap(value)
      const prefs = await this.openPrefs()
      await prefs.put(key, wrapped)
      await prefs.flush()
    } catch (e) {
      const err = e as BusinessError
      throw new Error(`SecureStore.set(${key}) failed: code=${err.code}`)
    }
  }

  async wipe(key: string): Promise<void> {
    try {
      const prefs = await this.openPrefs()
      await prefs.delete(key)
      await prefs.flush()
    } catch (e) {
      const err = e as BusinessError
      throw new Error(`SecureStore.wipe(${key}) failed: code=${err.code}`)
    }
  }

  async wipeAll(): Promise<void> {
    try {
      const prefs = await this.openPrefs()
      await prefs.clear()
      await prefs.flush()
    } catch (e) {
      const err = e as BusinessError
      throw new Error(`SecureStore.wipeAll prefs reset failed: code=${err.code}`)
    }
    // 删 HUKS key —— 不存在会抛错，包 try/catch 保幂等
    try {
      const opts: huks.HuksOptions = { properties: [] }
      await huks.deleteKeyItem(HUKS_ALIAS, opts)
    } catch (_e) {
      // 幂等：alias 不存在视为已删
      // scan-ignore: ARKTS-016
    }
  }

  // ─── HUKS 包装 / 解包 ─────────────────────────────────────

  /** 懒生成 AES-256-GCM key —— 首次 set 时建一次 */
  private async ensureKey(): Promise<void> {
    const checkOpts: huks.HuksOptions = { properties: [] }
    try {
      const ret = await huks.isKeyItemExist(HUKS_ALIAS, checkOpts)
      if (ret) {
        return
      }
    } catch (_e) {
      // 落空 → 走生成
      // scan-ignore: ARKTS-016
    }
    const generateOpts: huks.HuksOptions = {
      properties: [
        { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
        { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
        {
          tag: huks.HuksTag.HUKS_TAG_PURPOSE,
          value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT,
        },
        { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
        { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
      ],
    }
    try {
      await huks.generateKeyItem(HUKS_ALIAS, generateOpts)
    } catch (e) {
      const err = e as BusinessError
      throw new Error(`SecureStore.ensureKey HUKS generate failed: code=${err.code}`)
    }
  }

  /** UTF-8 string → `ivHex|cipherHex` */
  private async wrap(value: string): Promise<string> {
    // AES-GCM IV must come from a CSPRNG. Math.random() reused once
    // breaks the entire GCM mode (key recovery). cryptoFramework's
    // createRandom() is backed by the device hardware RNG.
    const iv: Uint8Array = cryptoFramework.createRandom().generateRandomSync(12).data
    const encoder = new util.TextEncoder()
    const plaintext = encoder.encodeInto(value)

    const opts: huks.HuksOptions = {
      properties: [
        { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
        { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
        { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT },
        { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
        { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
        { tag: huks.HuksTag.HUKS_TAG_IV, value: iv },
      ],
      inData: plaintext,
    }
    let handle: huks.HuksSessionHandle
    let result: huks.HuksReturnResult
    try {
      handle = await huks.initSession(HUKS_ALIAS, opts)
      result = await huks.finishSession(handle.handle, opts)
    } catch (e) {
      const err = e as BusinessError
      throw new Error(`SecureStore.wrap HUKS session failed: code=${err.code}`)
    }
    if (!result.outData) {
      throw new Error('SecureStore.wrap: HUKS finishSession 返回空 outData')
    }
    return bytesToHex(iv) + '|' + bytesToHex(result.outData)
  }

  /** `ivHex|cipherHex` → UTF-8 string */
  private async unwrap(combined: string): Promise<string> {
    const sep = combined.indexOf('|')
    if (sep < 0) {
      throw new Error('SecureStore.unwrap: 损坏的密文（缺 IV 分隔）')
    }
    const iv = hexToBytes(combined.substring(0, sep))
    const cipher = hexToBytes(combined.substring(sep + 1))

    const opts: huks.HuksOptions = {
      properties: [
        { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
        { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
        { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT },
        { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
        { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
        { tag: huks.HuksTag.HUKS_TAG_IV, value: iv },
      ],
      inData: cipher,
    }
    let handle: huks.HuksSessionHandle
    let result: huks.HuksReturnResult
    try {
      handle = await huks.initSession(HUKS_ALIAS, opts)
      result = await huks.finishSession(handle.handle, opts)
    } catch (e) {
      const err = e as BusinessError
      throw new Error(`SecureStore.unwrap HUKS session failed: code=${err.code}`)
    }
    if (!result.outData) {
      throw new Error('SecureStore.unwrap: HUKS finishSession 返回空 outData')
    }
    const decoder = util.TextDecoder.create('utf-8')
    return decoder.decodeToString(result.outData)
  }
}

// ─── hex 工具（ArkTS V1 无内置） ──────────────────────────────

const HEX: string = '0123456789abcdef'

function bytesToHex(bytes: Uint8Array): string {
  let out: string = ''
  for (let i = 0; i < bytes.length; i++) {
    const b = bytes[i]
    out += HEX.charAt((b >> 4) & 0xf)
    out += HEX.charAt(b & 0xf)
  }
  return out
}

function hexToBytes(hex: string): Uint8Array {
  if (hex.length % 2 !== 0) {
    throw new Error('hexToBytes: 奇数长度')
  }
  const out = new Uint8Array(hex.length / 2)
  for (let i = 0; i < out.length; i++) {
    const hi = HEX.indexOf(hex.charAt(i * 2))
    const lo = HEX.indexOf(hex.charAt(i * 2 + 1))
    if (hi < 0 || lo < 0) {
      throw new Error('hexToBytes: 非 hex 字符')
    }
    out[i] = ((hi << 4) | lo) & 0xff
  }
  return out
}
