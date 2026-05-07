// Test fixture · 验证 v0.5 误报修复 + inline-suppress
// 期望：文本模式下应该 0 命中（合法代码 + 抑制注释）

import { preferences } from '@kit.ArkData';

// STATE-009 误报检查：preferences.delete() 是合法 KV 删除，不应报
class PrefStore {
  private prefs: preferences.Preferences | null = null;

  async clear(): Promise<void> {
    await this.prefs!.delete('user_id');
    await this.prefs!.delete('user_name');
    await this.prefs!.clear();
  }

  // ARKTS-003 误报检查：Record<string, Object> 字面量索引赋值合法
  buildPayload(): object {
    const partObj: Record<string, Object> = {};
    partObj['type'] = 'image_url';
    partObj['image_url'] = { url: 'https://example.com/x.jpg' };
    return partObj;
  }

  // ARKTS-RECORD 误报检查：空 = {} 在 ArkTS 合法
  newCache(): Record<string, string[]> {
    const cache: Record<string, string[]> = {};   // 空字面量，合法
    return cache;
  }

  // inline-suppress 测试：上一行带 // scan-ignore: RULE
  async destroyResources(): Promise<void> {
    // scan-ignore: ARKTS-016
    try { await this.prefs!.flush() } catch (_) { /* 资源清理时吞错合理 */ }
  }
}
