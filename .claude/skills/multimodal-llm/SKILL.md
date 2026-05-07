---
name: multimodal-llm
verified_against: harmonyos-6.0.2-api22  # last sync 2026-05-07
description: |
  在鸿蒙 ArkTS 里调多模态 LLM API（OpenAI Vision / Whisper / DALL-E、Anthropic Vision、Gemini 等）的领域专项。
  **激活条件**（满足任一即激活）：
    - 用户写"调 GPT-4 Vision / Claude Vision / Gemini Vision"
    - 用户写"上传音频转文字 / Whisper / 语音识别 API"
    - 用户写"DALL-E / Stable Diffusion / 图像生成 API"
    - 代码里出现 `ChatMessage.content`、`role: 'user'`、`stream: true` 等 LLM payload 字段
    - 代码涉及 SSE 流式解析（`text/event-stream` / `data: ` 前缀行）
    - 涉及 multipart/form-data 上传（音频 / 视频 / 大文件给 LLM 服务）
  **不激活**：纯文本 LLM 单轮问答（用普通 @kit.NetworkKit http POST 即可）；本地推理（不调云端 API）。
---

# 多模态 LLM 调用 · ArkTS 领域专项

> 鸿蒙写 LLM 客户端跟 Web / Node.js 写最大的区别：**ArkTS 严格类型不允许 union**，且 OHPM 没有 `axios` / `openai-sdk`，所有 HTTP 都得靠 `@kit.NetworkKit` 自己拼。
>
> 本 SKILL 给"约束 + 关键模式"，不给完整 SDK 代码（每家 API 演化快，固定代码会过期）。

## 一、Vision API 的 union content 难题

OpenAI / Anthropic Vision 的 `messages[].content` 在文本时是 string、在含图时是 `Array<{type, text|image_url}>`。**TypeScript / Python 写法**：

```typescript
content: string | ContentPart[]
```

**ArkTS 写法**：拒绝 union。改双字段 + 自定义序列化：

```typescript
class ChatMessage {
  role: string = 'user';
  // 纯文本时填这个
  contentText: string = '';
  // 多模态时填这个；与 contentText 互斥
  contentParts: ContentPart[] = [];

  // 序列化为 OpenAI 期望的格式
  toApiPayload(): object {
    if (this.contentParts.length > 0) {
      return { role: this.role, content: this.contentParts.map(p => p.toApiPart()) };
    }
    return { role: this.role, content: this.contentText };
  }
}

class ContentPart {
  type: 'text' | 'image_url' = 'text';
  text: string = '';
  imageUrl: string = '';   // base64 data URL 或 https://

  toApiPart(): object {
    if (this.type === 'image_url') {
      return { type: 'image_url', image_url: { url: this.imageUrl } };
    }
    return { type: 'text', text: this.text };
  }
}
```

**关联规则**：[`ARKTS-NO-UNION-CONTENT`](../arkts-rules/references/spec-quick-ref.md) 自动扫描会命中 union 写法。

## 二、SSE 流式解析（文本流）

LLM API 的 `stream: true` 返回 `text/event-stream`：每条消息 `data: {...}\n\n`，最后 `data: [DONE]`。

### 标准 ArkTS 解析骨架

```typescript
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xBEEF;

async function streamChat(
  url: string,
  payload: object,
  apiKey: string,
  onDelta: (text: string) => void,
): Promise<void> {
  const req = http.createHttp();

  // 注意：@kit.NetworkKit 的 http 默认是非流式的；流式要用 requestInStream
  try {
    let buffer = '';
    const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });

    req.on('dataReceive', (data: ArrayBuffer) => {
      const chunk = decoder.decodeToString(new Uint8Array(data), { stream: true });
      buffer += chunk;
      // 按 \n\n 切包
      let idx: number;
      while ((idx = buffer.indexOf('\n\n')) >= 0) {
        const event = buffer.slice(0, idx);
        buffer = buffer.slice(idx + 2);
        const line = event.trim();
        if (!line.startsWith('data: ')) continue;
        const body = line.slice(6).trim();
        if (body === '[DONE]') return;
        try {
          const parsed = JSON.parse(body) as ChatStreamChunk;
          const delta = parsed.choices?.[0]?.delta?.content;
          if (delta) onDelta(delta);
        } catch (e) { /* 不完整 chunk 等下一轮 */ }
      }
    });

    await req.requestInStream(url, {
      method: http.RequestMethod.POST,
      header: {
        'Authorization': `Bearer ${apiKey}`,        // ⚠️ 别在日志打这个
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      },
      extraData: JSON.stringify(payload),
    });
  } catch (e) {
    hilog.error(DOMAIN, 'llm', 'stream failed: %{public}s', JSON.stringify(e));
    throw e;
  } finally {
    req.destroy();   // KIT-001 必须 destroy
  }
}

class ChatStreamChunk {
  choices: ChatStreamChoice[] = [];
}
class ChatStreamChoice {
  delta: ChatStreamDelta = new ChatStreamDelta();
}
class ChatStreamDelta {
  content: string = '';
}
```

**关键约束**：
- 用 `decodeToString({ stream: true })`——**不是 deprecated 的 `decodeWithStream`**（[ARKTS-DEPRECATED-DECODE](../arkts-rules/references/spec-quick-ref.md)）
- buffer 拼接处理半 chunk
- `req.destroy()` 必须在 finally（[KIT-001](../arkts-rules/references/spec-quick-ref.md)）
- `Authorization` header 不要打 hilog %{public}（[SEC-002](../arkts-rules/references/spec-quick-ref.md)）

## 三、Whisper / 多媒体上传（multipart/form-data）

@kit.NetworkKit 的 http **不直接支持 multipart**。要么自己拼字节流，要么用 `request.uploadFile`：

```typescript
import { request } from '@kit.BasicServicesKit';

// 推荐：把音频写到 cacheDir，用 uploadFile
async function uploadAudioToWhisper(filePath: string, apiKey: string): Promise<string> {
  const ctx = getContext();
  const config: request.UploadConfig = {
    url: 'https://api.openai.com/v1/audio/transcriptions',
    header: { 'Authorization': `Bearer ${apiKey}` },
    method: 'POST',
    files: [{
      filename: 'audio.m4a',
      name: 'file',
      uri: `internal://cache/${filePath}`,
      type: 'audio/m4a',
    }],
    data: [
      { name: 'model', value: 'whisper-1' },
      { name: 'language', value: 'zh' },
    ],
  };
  // ... 监听 complete 事件拿响应
}
```

> 自拼 multipart 字节流也行（直接 `requestInStream` + `extraData` 是 ArrayBuffer），但代码量大于上面的 `uploadFile`。

## 四、DALL-E / 图像生成 · base64 → Attachment

DALL-E 返回 `b64_json: '...'` 或 `url: '...'`。鸿蒙里要保存到 cacheDir 当 attachment：

```typescript
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

async function saveBase64Image(b64: string, name: string): Promise<string> {
  const ctx = getContext();
  const filePath = `${ctx.cacheDir}/${name}`;
  const decoder = util.Base64Helper.create();
  const bytes = await decoder.decode(b64);
  const file = await fs.open(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
  try {
    await fs.write(file.fd, bytes.buffer);
  } finally {
    await fs.close(file.fd);
  }
  return filePath;
}
```

**关键**：写完 fd 必须 close（同 [DB-001](../arkts-rules/references/spec-quick-ref.md) 的资源释放精神）。

## 五、API key 必须 HUKS 加密

直接 `Preferences.put('apiKey', plain)` 会被 AGC 拒（[SEC-001](../arkts-rules/references/spec-quick-ref.md)）。完整模式见 [`runtime-pitfalls`](../runtime-pitfalls/SKILL.md) § 六。

## 六、错误处理 · 一份能上架的最小骨架

```typescript
async function chatWithFallback(...): Promise<string> {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      return await callApi(...);
    } catch (e) {
      const err = e as BusinessError;
      // 区分错误类型，决定是否重试
      if (err.code === 401) throw e;          // 鉴权错，重试也无意义
      if (err.code === 429) {                 // rate limit，退避
        await sleep(1000 * Math.pow(2, attempt));
        continue;
      }
      if (attempt === 2) throw e;             // 重试满
      await sleep(500 * (attempt + 1));
    }
  }
  throw new Error('unreachable');
}
```

**对应 AGC 拒因**：[`AGC-RJ-018`](../../../07-publishing/checklist-2026-rejection-top20.md) 网络异常处理缺失。

## 进一步参考

- 工程层装配陷阱：[`runtime-pitfalls`](../runtime-pitfalls/SKILL.md)
- 实战 case study：[`docs/case-studies/llm-chat-app.md`](../../../docs/case-studies/llm-chat-app.md)
- @kit.NetworkKit 完整文档：`upstream-docs/.../reference/apis-network-kit/`
