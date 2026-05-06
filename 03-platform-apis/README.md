# Platform APIs · HarmonyOS 系统能力索引

HarmonyOS 通过 **Kit**（API 12+ 推荐）和 **@ohos.\* 命名空间**（旧式）暴露系统能力。本目录给出常见任务到 API 的映射，并指向 `upstream-docs/` 中的官方权威说明。

## 1. Kit 体系总览

每个 Kit 是一组相关 API 的聚合，便于按业务场景查找：

| Kit | 内容举例 | 本地参考 |
| --- | --- | --- |
| **AbilityKit** | UIAbility / Want / EventHub / 权限 | `upstream-docs/.../reference/apis-ability-kit/` |
| **ArkUI** | 窗口、组件管理、UIContext | `upstream-docs/.../reference/apis-arkui/` |
| **ArkTS** | TaskPool / Worker / Container 类型 | `upstream-docs/.../reference/apis-arkts/` |
| **NetworkKit** | http / socket / connection / webSocket | `upstream-docs/.../reference/apis-network-kit/` |
| **ConnectivityKit** | wifi / bluetooth / nfc | `upstream-docs/.../reference/apis-connectivity-kit/` |
| **MediaKit** | AVPlayer / AVRecorder / Camera | `upstream-docs/.../reference/apis-media-kit/` |
| **CameraKit** | 相机预览 / 拍照 / 录像 | `upstream-docs/.../reference/apis-camera-kit/` |
| **ImageKit** | 解码 / 编码 / 像素操作 | `upstream-docs/.../reference/apis-image-kit/` |
| **AudioKit** | AudioRenderer / Capturer | `upstream-docs/.../reference/apis-audio-kit/` |
| **CoreFileKit** | 文件、目录、元数据 | `upstream-docs/.../reference/apis-core-file-kit/` |
| **DataStorage** / **PersistentStore** | preferences / relationalStore (SQLite-like) / distributedKVStore | `upstream-docs/.../reference/apis-arkdata/` |
| **LocationKit** | GPS / 定位 | `upstream-docs/.../reference/apis-location-kit/` |
| **NotificationKit** | 通知中心、徽标 | `upstream-docs/.../reference/apis-notification-kit/` |
| **PushKit** | 远程推送（华为推送服务） | `upstream-docs/.../reference/apis-push-kit/` |
| **SecurityKit** | 加密、证书、安全输入 | `upstream-docs/.../reference/apis-security-kit/` |
| **AccessibilityKit** | 无障碍 | `upstream-docs/.../reference/apis-accessibility-kit/` |
| **PerformanceAnalysisKit** | hilog / hiTraceMeter / hidumper | `upstream-docs/.../reference/apis-performance-analysis-kit/` |
| **TestKit** | UI Test / unit test API | `upstream-docs/.../reference/apis-test-kit/` |
| **GraphicsKit** / **ArkGraphics2D/3D** | 2D / 3D 渲染 | `upstream-docs/.../reference/apis-arkgraphics2d/` |
| **TelephonyKit** | 短信 / 通话 / SIM | `upstream-docs/.../reference/apis-telephony-kit/` |
| **DeviceManagementKit** | 多设备发现、协同 | `upstream-docs/.../reference/apis-device-management-kit/` |
| **MdmKit** | 企业管理 | `upstream-docs/.../reference/apis-mdm-kit/` |
| **WallpaperKit** / **WindowManagement** | 壁纸 / 窗口 | `upstream-docs/.../reference/apis-window-kit/` |
| **MapKit** | 地图（华为地图） | docs.huawei.com/petalmap |
| **AccountKit** | 华为帐号登录 | docs.huawei.com/account |

完整清单：在 `upstream-docs/openharmony-docs/zh-cn/application-dev/reference/` 下按 `apis-*-kit` / `apis-*` 命名。

## 2. 任务速查

| 我想做什么 | 用什么 | 示例 |
| --- | --- | --- |
| 发 HTTP 请求 | `@kit.NetworkKit` 的 `http` | 见下方 §3.1 |
| 读写本地文件 | `@kit.CoreFileKit` 的 `fs` | 见 §3.2 |
| 持久化 KV | `@kit.ArkData` 的 `preferences` | 见 §3.3 |
| 关系型存储 | `@kit.ArkData` 的 `relationalStore` | SQLite 风格 |
| 跳页面 | `@kit.ArkUI` 的 `Navigation` 或 `router` | 见 ArkUI README |
| 拍照 | `@kit.CameraKit` 或简化 `cameraPicker` | |
| 选媒体文件 | `@kit.CoreFileKit` 的 `picker` | |
| 申请权限 | `@kit.AbilityKit` 的 `abilityAccessCtrl` | 见 §3.4 |
| 推送 | `@kit.PushKit` | 需要 AGC 推送服务 |
| 定位 | `@kit.LocationKit` | 需要 LOCATION 权限 |
| 蓝牙 / NFC | `@kit.ConnectivityKit` | |
| 多设备协同 | `@kit.AbilityKit` + `DistributedDataKit` | |
| 后台任务 | `@kit.BackgroundTasksKit` | |
| 闹钟 / 定时 | `@kit.BackgroundTasksKit` 的 `reminderAgent` | |
| WebView | ArkUI `Web` 组件 + `@kit.ArkWeb` | |

## 3. 常用代码片段

### 3.1 HTTP 请求

```typescript
import { http } from '@kit.NetworkKit';

const httpRequest = http.createHttp();
const res = await httpRequest.request(
  'https://api.example.com/data',
  {
    method: http.RequestMethod.GET,
    header: { 'Content-Type': 'application/json' },
    expectDataType: http.HttpDataType.OBJECT,
    readTimeout: 10000,
    connectTimeout: 10000,
  }
);
console.log('code', res.responseCode);
console.log('data', res.result);
httpRequest.destroy();
```

需要权限：`ohos.permission.INTERNET`（在 `module.json5` 的 `requestPermissions` 中声明）。

### 3.2 文件读写

```typescript
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

const ctx = getContext(this) as common.UIAbilityContext;
const path = ctx.filesDir + '/note.txt';

fs.writeSync(fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE).fd,
             'hello harmony', { encoding: 'utf-8' });

const text = fs.readTextSync(path, { encoding: 'utf-8' });
console.log(text);
```

### 3.3 Preferences（KV 存储）

```typescript
import { preferences } from '@kit.ArkData';

const ctx = getContext(this) as Context;
const pref = await preferences.getPreferences(ctx, 'mystore');
await pref.put('lastOpen', Date.now());
await pref.flush();

const t = await pref.get('lastOpen', 0) as number;
```

### 3.4 申请权限

```typescript
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';

const perms: Permissions[] = [
  'ohos.permission.LOCATION',
  'ohos.permission.READ_MEDIA',
];

const am = abilityAccessCtrl.createAtManager();
const res = await am.requestPermissionsFromUser(getContext(this), perms);
const granted = res.authResults.every(r => r === 0);
if (!granted) console.warn('missing permissions');
```

`module.json5` 也必须在 `requestPermissions` 中预先声明，否则 API 会拒绝。

## 4. 权限速查

常见权限 → `module.json5` 字段 `requestPermissions`：

| 用途 | 权限 |
| --- | --- |
| 联网 | `ohos.permission.INTERNET` |
| 读相册 | `ohos.permission.READ_MEDIA` / `READ_IMAGEVIDEO` |
| 写相册 | `ohos.permission.WRITE_MEDIA` |
| 麦克风 | `ohos.permission.MICROPHONE` |
| 相机 | `ohos.permission.CAMERA` |
| 定位 | `ohos.permission.LOCATION` / `APPROXIMATELY_LOCATION` / `LOCATION_IN_BACKGROUND` |
| 蓝牙 | `ohos.permission.ACCESS_BLUETOOTH` |
| 通讯录 | `ohos.permission.READ_CONTACTS` / `WRITE_CONTACTS` |
| 通知 | `ohos.permission.PUBLISH_AGENT_REMINDER` |
| 后台任务 | `ohos.permission.KEEP_BACKGROUND_RUNNING` |

完整列表：`upstream-docs/.../security/AccessToken/permissions-for-all.md`

## 5. SystemCapability 检测

不同设备形态 API 可用性有差别，调用前判断：

```typescript
import { canIUse } from '@kit.AbilityKit';
if (canIUse('SystemCapability.Multimedia.Camera.Core')) {
  // 调用相机相关 API
} else {
  // 提示设备不支持
}
```

## 6. 异常码

所有 API 返回的 `BusinessError` 含 `code` 与 `message`：

```typescript
import { BusinessError } from '@kit.BasicServicesKit';

try {
  await someApi();
} catch (e) {
  const err = e as BusinessError;
  if (err.code === 201) {
    // 通用：权限被拒
  }
}
```

错误码表分散在各 API 文档底部。

## 7. 进一步

- 系统能力分类总览：`upstream-docs/openharmony-docs/zh-cn/application-dev/application-dev-guide.md`
- API 索引（按字母）：`upstream-docs/.../reference/apis-*` 各子目录的 Readme
- HarmonyOS Design 设备能力：`upstream-docs/zh-cn/design/`
