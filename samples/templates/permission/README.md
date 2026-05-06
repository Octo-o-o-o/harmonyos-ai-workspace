# Recipe · 权限申请（位置 / 相机 / 通知 / 麦克风）

> verified_against: harmonyos-6.0.2-api22 · last sync 2026-05-07
>
> 关联规则：`AGC-RJ-002`（权限申请合理性）、`PERM-001..005`（权限管理 5 条）

## 约束

1. **每个 `ohos.permission.*` 在 UI 中必须有用途说明**（否则 AGC 拒）
2. **用户拒绝后必须有可继续使用的退路**（不能直接退出 / 强制重启）
3. **禁止"一次申请所有权限"**——只在功能即将使用时申请
4. **敏感权限（位置 / 麦克风 / 相机）申请前必须先用 `promptAction.showDialog` 解释**
5. **`module.json5` 里的 `requestPermissions` 数组必须最小化**——不用就不要列

## 完整代码

见 [`permission-helper.ets`](permission-helper.ets)。

## 集成步骤

### 1. `entry/src/main/module.json5` 加权限声明

```json5
{
  "module": {
    "requestPermissions": [
      {
        "name": "ohos.permission.LOCATION",
        "reason": "$string:perm_location_reason",
        "usedScene": {
          "abilities": ["EntryAbility"],
          "when": "always"
        }
      },
      {
        "name": "ohos.permission.CAMERA",
        "reason": "$string:perm_camera_reason"
      },
      {
        "name": "ohos.permission.MICROPHONE",
        "reason": "$string:perm_mic_reason"
      },
      {
        "name": "ohos.permission.NOTIFICATION",
        "reason": "$string:perm_notification_reason"
      }
    ]
  }
}
```

### 2. `entry/src/main/resources/base/element/string.json` 加文案

```json
{
  "string": [
    { "name": "perm_location_reason", "value": "用于推荐附近的服务点；拒绝后仍可手动输入" },
    { "name": "perm_camera_reason",   "value": "用于扫码 / 拍照；拒绝后可改用相册" },
    { "name": "perm_mic_reason",      "value": "用于语音输入；拒绝后可改用键盘" },
    { "name": "perm_notification_reason", "value": "用于推送提醒；拒绝后仍可在 app 内查看" }
  ]
}
```

### 3. 在调用点引用（不要在 `aboutToAppear` 里一次申请全部）

```typescript
import { requestPermissionWithUI } from './permission-helper';

Button('开启位置')
  .onClick(async () => {
    const ok = await requestPermissionWithUI('ohos.permission.LOCATION', '推荐附近服务');
    if (!ok) {
      // 拒绝兜底：让用户手动输入位置
    } else {
      // 正常开始用定位
    }
  })
```

## 反模式（钩子 / review 会命中）

- ❌ 在 `aboutToAppear()` 里一次申请所有权限 → AGC 拒
- ❌ 申请前不解释用途 → AGC 拒
- ❌ 拒绝后 `app.exit()` 强退出 → AGC 拒
- ❌ `module.json5` 列了用不到的权限 → AGC 拒（最小化原则）

## 进一步参考

- 官方权限说明：`upstream-docs/openharmony-docs/zh-cn/application-dev/security/AccessToken/`
- 提审拒因 `AGC-RJ-002`：[`07-publishing/checklist-2026-rejection-top20.md`](../../../07-publishing/checklist-2026-rejection-top20.md)
