// Test fixture · 触发 v0.4 PrivateTalk 实战反馈规则
// 期望钩子命中：
//   ARKTS-RECORD（#1）
//   ARKTS-AWAIT-TRY（#3）
//   ARKTS-DEPRECATED-PICKER（#10）
//   ARKTS-DEPRECATED-DECODE（#11）
//   ARKTS-NO-UNION-CONTENT（#9）

import { picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

// ARKTS-RECORD: Record 字面量初始化
class Bad {
  // 字段示意
  config: Record<string, string> = { mode: 'dark', lang: 'zh' };  // ← 应改 Map.set 或先声明 class
}

// ARKTS-AWAIT-TRY: 全文没有 try 块但有 await
async function fetchData(url: string): Promise<string> {
  const resp = await fetch(url);   // ← codeLinter 会报 Function may throw
  return await resp.text();
}

// ARKTS-DEPRECATED-PICKER: HarmonyOS 6 弃用
async function pickPhoto(): Promise<void> {
  const p = new picker.PhotoViewPicker();    // ← 应改 photoAccessHelper.PhotoViewPicker
}

// ARKTS-DEPRECATED-DECODE: 弃用 API
function decode(buf: Uint8Array): string {
  const dec = util.TextDecoder.create('utf-8');
  return dec.decodeWithStream(buf);          // ← 应改 decodeToString({stream:true})
}

// ARKTS-NO-UNION-CONTENT: union 字段在 ArkTS 不允许
interface ChatMessage {
  role: string;
  content: string | object[];                 // ← ArkTS 拒绝；改双字段 contentText/contentParts
}
