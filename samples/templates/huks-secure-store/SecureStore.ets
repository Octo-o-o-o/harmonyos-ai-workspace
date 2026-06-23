// SecureStore.ets
// 最小可用 HUKS 加密本地存储（OctoDesk Mobile 的简化版）
//
// 模式：
//   - 单条字符串值 → @kit.ArkData preferences 落盘
//   - 写入前用 HUKS AES-256-GCM 包装（key 在 HUKS 内不可导出）
//   - 存储格式：`gcm2|nonceHex|tagHex|cipherHex`（版本化封套）
//   - GCM 用 HUKS_TAG_NONCE（不是 IV）+ 显式 HUKS_TAG_AE_TAG 认证 tag；
//     tag 返回位置不固定（独立 property 或追加在 outData 尾），两者都兜
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
const GCM_ENVELOPE_V2: string = 'gcm2'   // 版本化封套魔数前缀
const GCM_TAG_BYTES: number = 16         // AES-GCM 认证 tag 固定 16 字节

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

  /** UTF-8 string → `gcm2|nonceHex|tagHex|cipherHex` */
  private async wrap(value: string): Promise<string> {
    // AES-GCM 的 nonce 必须来自 CSPRNG —— Math.random() 重用一次就彻底 break
    // GCM（key recovery）。cryptoFramework.createRandom() 走设备硬件 RNG。
    // 注意：GCM 用 HUKS_TAG_NONCE，不是 HUKS_TAG_IV（IV 是 CBC/CTR 的命名）。
    const nonce: Uint8Array = cryptoFramework.createRandom().generateRandomSync(12).data
    const encoder = new util.TextEncoder()
    const plaintext = encoder.encodeInto(value)

    const opts: huks.HuksOptions = {
      properties: [
        { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
        { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
        { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT },
        { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
        { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
        { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
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
    // GCM 认证 tag（16B）返回位置不固定：可能是独立的 HUKS_TAG_AE_TAG property，
    // 也可能直接追加在 outData 末尾。两者都兜，否则换 ROM / API 版本就解不开。
    let cipherBytes: Uint8Array = result.outData
    let aeTagBytes: Uint8Array | null = findHuksBytesParam(result.properties, huks.HuksTag.HUKS_TAG_AE_TAG)
    if (aeTagBytes === null && result.outData.length > GCM_TAG_BYTES) {
      const tagOffset = result.outData.length - GCM_TAG_BYTES
      cipherBytes = result.outData.slice(0, tagOffset)
      aeTagBytes = result.outData.slice(tagOffset)
    }
    if (aeTagBytes === null) {
      throw new Error('SecureStore.wrap: 未取到 GCM 认证 tag（HUKS_TAG_AE_TAG）')
    }
    // 版本化封套：魔数前缀方便日后格式升级时识别
    return GCM_ENVELOPE_V2 + '|' + bytesToHex(nonce) + '|' + bytesToHex(aeTagBytes) + '|' + bytesToHex(cipherBytes)
  }

  /** `gcm2|nonceHex|tagHex|cipherHex` → UTF-8 string */
  private async unwrap(combined: string): Promise<string> {
    const parts = combined.split('|')
    if (parts.length !== 4 || parts[0] !== GCM_ENVELOPE_V2) {
      // 若你有更早的 `ivHex|cipherHex` 历史数据，在这里加一条 fallback：用
      // HUKS_TAG_IV + 2 段解码（见 05-best-practices/bridge-integration-pitfalls.md §8）。
      throw new Error('SecureStore.unwrap: 损坏或未知格式的密文封套')
    }
    const nonce = hexToBytes(parts[1])
    const aeTag = hexToBytes(parts[2])
    const cipher = hexToBytes(parts[3])

    const opts: huks.HuksOptions = {
      properties: [
        { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
        { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
        { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT },
        { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
        { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
        { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
        { tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: aeTag },
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

/** 从 HUKS finishSession 返回的 properties 里取某个 tag 的 bytes（找不到返回 null） */
function findHuksBytesParam(params: Array<huks.HuksParam> | undefined, tag: huks.HuksTag): Uint8Array | null {
  if (!params) {
    return null
  }
  for (let i = 0; i < params.length; i++) {
    const value = params[i].value
    if (params[i].tag === tag && value instanceof Uint8Array) {
      return value
    }
  }
  return null
}
