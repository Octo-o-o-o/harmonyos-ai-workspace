# error-event-builder

> 最小可跑骨架：HarmonyOS NEXT (ArkTS V1) bridge plugin 中如何抽 per-service
> `private reportXxx(...)` / `failAndXxx(...)` builder helper，把"每个调用点
> 4-8 行 `new Payload + 字段 assign + emit`" 收成 1 行 delegate。
>
> 配套文档：`05-best-practices/bridge-integration-pitfalls.md` §12。

## 场景

ArkTS V1 强 type-strictness，禁止 object literal 给 bridge event payload。
每个调用点都展开为 `new BridgeXxxPayload()` + N 行 `payload.field = value`
+ `this.emit(payload)`。OctoDesk UploadController 2026-05 audit 单文件 8 处
4 行模板（~32 行噪音），handler 主线逻辑被埋没。

## 反模式 vs 标准做法

详见 `ErrorEventBuilder.ets`（含 OctoDesk UploadController-style upload
service skeleton + reportError + failAndUnregister 两 helper + 4 个不同状态的
调用点对比）。

骨架要点：

1. `private reportError(corrId, code, message, retryable)` — 给"未注册前 fail"
   场景（不清理 active map）
2. `private failAndUnregister(corrId, code, message, retryable)` — 给"已注册后
   fail"场景，先 reportError 再清理
3. 调用点从 5 行变 1 行
4. **不要**抽跨 service 通用 `reportBridgeError<T>(emit, P, fields)` —— ArkTS
   V1 + ESObject 泛型 erase 后失字段名 / 类型保护，回到 untyped JS

## 边界

- 仅当 service 内 ≥ 3 处重复才抽 helper
- success payload 通常各 service 字段差异大，不强抽
- 命名保留语义差异：`reportError` vs `failAndUnregister` 反映"未注册 / 已注册后失败"两态

## 反哺溯源

抽出自 OctoDesk repo [`apps/harmonyos/entry/src/main/ets/upload/UploadController.ets`](https://github.com/Octo-o-o-o/OctoDesk/blob/main/apps/harmonyos/entry/src/main/ets/upload/UploadController.ets)
2026-05-24 wave G3 refactor (commit `3d4eb635`)。
