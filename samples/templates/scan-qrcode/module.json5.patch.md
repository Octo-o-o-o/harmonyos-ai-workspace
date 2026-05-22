# `module.json5` 补丁 —— scan-qrcode

ScanKit 必须申请相机权限。在你的 `entry/src/main/ets/.../module.json5` 的
`module` 对象内追加 `requestPermissions`（如果已经有这个数组，把下面这条 push 进去）：

```json5
{
  "module": {
    // ... 你的其他配置（name / type / pages / abilities 等）
    "requestPermissions": [
      {
        "name": "ohos.permission.CAMERA",
        "reason": "$string:permission_camera_reason",
        "usedScene": {
          "abilities": ["EntryAbility"],
          "when": "inuse"
        }
      }
    ]
  }
}
```

同时在 `entry/src/main/resources/base/element/string.json` 加 `permission_camera_reason`：

```json5
{
  "string": [
    {
      "name": "permission_camera_reason",
      "value": "扫描二维码以加入设备 / 完成配对"
    }
  ]
}
```

## 用户拒权后的恢复路径

HarmonyOS 6.x **没有** Android 的 `shouldShowRationale` API。一旦用户在系统弹窗里拒绝相机权限，只能引导用户去系统设置页打开，**不能在 app 内再次弹原生权限框**。

`ScanPlugin` 的 `permission_denied` outcome 已经把 `canOpenSettings: true` 设上了；UI 端拿到这个 outcome 应该展示一个"前往设置"按钮，跳转用：

```typescript
import { common } from '@kit.AbilityKit'

async function openAppSettings(ctx: common.UIAbilityContext): Promise<void> {
  await ctx.startAbility({
    bundleName: ctx.abilityInfo.bundleName,
    abilityName: 'com.huawei.hmos.settings.MainAbility',
    uri: 'application_info_entry',
    parameters: { pushParams: ctx.abilityInfo.bundleName },
  })
}
```

（实际跳转方式以华为最新 [`apis-ability-kit`](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-ability-kit/js-apis-app-ability-uiAbility.md) 文档为准；不同 HarmonyOS 大版本可能有微调。）

## AGC 审核要点

- `reason` 必须用资源引用 `$string:...`，不要硬编码字符串 —— 否则会撞 `AGC-RJ-014`（i18n 资源）
- `usedScene.when` 一般是 `"inuse"`（前台使用）；扫码场景**不应**用 `"always"`，会被审核 P0 卡（"权限申请范围超出业务需要"）
- "扫码业务"这种用户主动触发的能力，AGC 通常不会要求 `requestPermissionOnApplicationLaunch` 兜底；保持 lazy 申请即可
