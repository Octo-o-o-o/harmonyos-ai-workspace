# AppGallery 提审 · Top 20 拒因清单（2026 版）

> 综合 AGC 官方审核标准、华为开发者论坛真实拒因案例、CSDN / 掘金多个开发者复盘，**按出现频率排序**。
>
> 提审前对照本清单走一遍，能避开 80% 以上的"上传后被拒"。
>
> 每条带稳定 ID（`AGC-RJ-001` ...），review skill 与 `harmonyos-review` 报告中可引用。

## 高频拒因（前 10）

### `AGC-RJ-001` 隐私政策缺失或不可访问

- 必须有**独立 HTTPS URL**（不能放在 app 内）
- 首次启动**必须弹窗**展示，用户明确同意才能继续
- 政策中必须列出：收集哪些个人信息、第三方 SDK 列表、是否跨境、保存周期
- 修复：用 [华为开发者隐私模板](https://developer.huawei.com/consumer/cn/agconnect/help/privacy-policy/) 起草，部署到自有域名

**最小代码片段**（首次启动弹窗 + 持久化同意状态）：

```typescript
// entry/src/main/ets/pages/Index.ets
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';

const PRIVACY_KEY = 'privacy_accepted_v1';   // 隐私政策版本变更时改 v2

@Entry
@Component
struct Index {
  @State accepted: boolean = false;
  @State showDialog: boolean = false;

  async aboutToAppear(): Promise<void> {
    const store = await preferences.getPreferences(getContext(this), 'app');
    this.accepted = await store.get(PRIVACY_KEY, false) as boolean;
    this.showDialog = !this.accepted;
  }

  async accept(): Promise<void> {
    const store = await preferences.getPreferences(getContext(this), 'app');
    await store.put(PRIVACY_KEY, true);
    await store.flush();
    this.accepted = true;
    this.showDialog = false;
  }

  build() {
    Stack() {
      // 主 UI
      if (this.showDialog) {
        // 同意弹窗：含"查看隐私政策"按钮跳到外部 HTTPS URL
      }
    }
  }
}
```

### `AGC-RJ-002` 权限申请缺合理性

- 申请的每个 `ohos.permission.*` 都要在 UI 中**说明用途**
- 用户拒绝后必须有**可继续使用的退路**
- 禁止"一次申请所有权限"
- 修复：在 `aboutToAppear` 后用 `requestPermissionsFromUser` 单独申请，每次申请前给 1-2 句解释

**最小代码片段**（按需申请 + 拒绝兜底）：

```typescript
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

async function requestLocation(ctx: common.UIAbilityContext): Promise<boolean> {
  const perm: Permissions = 'ohos.permission.LOCATION';
  const atManager = abilityAccessCtrl.createAtManager();

  // 1. 先给用户解释（必须！否则 AGC 会拒）
  const ok = await promptAction.showDialog({
    title: '需要定位权限',
    message: '用于推荐附近的服务点；拒绝后仍可手动输入位置。',
    buttons: [{ text: '不允许', color: '#666' }, { text: '允许', color: '#0A59F7' }]
  });
  if (ok.index !== 1) return false;

  // 2. 申请
  const result = await atManager.requestPermissionsFromUser(ctx, [perm]);
  return result.authResults[0] === 0;
}

// 拒绝后的兜底：UI 给"手动输入"入口，不要直接报错退出
```

### `AGC-RJ-003` 实名认证 / 资质缺失

- 涉及金融、游戏、医疗、新闻、社交、电商的 app 需要对应资质
- 个人开发者**不能**上架金融、医疗类
- 修复：在 AGC 应用信息页上传资质扫描件；类目选错的需要重新提交

### `AGC-RJ-004` 应用图标 / 启动图违规

- 图标不能用华为系统图标 / 商标
- 启动图不能含**广告内容、第三方 logo**
- 图标必须**最大 1024×1024 PNG**，圆角自动处理
- 修复：用 DevEco "图标制作" 工具或 AGC 在线工具

### `AGC-RJ-005` 闪退 / ANR 高发

- AGC 自动跑稳定性测试，crash 率 > 0.5% 拒
- ANR > 0.3% 拒
- 修复：提交前在多机型（Mate / Pura / Nova）跑 30 分钟以上压测；用 `hilog` 看 crash 日志

**最小代码片段**（顶层 try/catch + BusinessError 类型断言 + 异步任务取消）：

```typescript
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xBEEF;

// ❌ 容易闪退：未处理的 Promise rejection
async function badFetch() {
  const data = await http.createHttp().request(url);   // 网络异常会直接抛
  return JSON.parse(data.result as string);
}

// ✅ 健壮版本
async function goodFetch(url: string): Promise<UserData | null> {
  try {
    const resp = await http.createHttp().request(url, { connectTimeout: 5000 });
    if (resp.responseCode !== 200) {
      hilog.warn(DOMAIN, 'API', '%{public}s HTTP %{public}d', url, resp.responseCode);
      return null;
    }
    return JSON.parse(resp.result as string) as UserData;
  } catch (e) {
    const err = e as BusinessError;
    hilog.error(DOMAIN, 'API', 'code=%{public}d msg=%{public}s', err.code, err.message);
    return null;
  }
}

// 长任务必须支持取消（避免 ANR）
class PageState {
  private cancelled = false;
  aboutToDisappear(): void { this.cancelled = true; }   // 页面切走时停掉

  async loadData(): Promise<void> {
    for (let i = 0; i < items.length; i++) {
      if (this.cancelled) return;
      // ... 处理 item
    }
  }
}
```

### `AGC-RJ-006` API Level 与 minSdk 不匹配

- `compileSdkVersion ≥ targetSdkVersion ≥ minSdkVersion`
- 用了 API 21+ 新特性但 minSdk 是 12，没有 `canIUse('SystemCapability.X')` 守护 → 拒
- 修复：要么提高 minSdk；要么加守护

### `AGC-RJ-007` 调试日志泄漏

- release 包不能含 `console.log`
- `hilog` 不能用 `%{public}` 输出敏感字段（口令 / token / 身份证）
- 修复：跑 `hvigorw assembleApp -p buildMode=release` 时启用混淆 + log 剥离

**最小代码片段**（敏感字段脱敏 + 混淆配置）：

```typescript
// ❌ 拒因示例：明文输出口令
hilog.info(DOMAIN, 'auth', '%{public}s', `password=${pwd}`);

// ❌ token 用 %{public} 打出来也会被拒
hilog.info(DOMAIN, 'auth', 'token=%{public}s', token);

// ✅ 敏感字段必须用 %{private} 或彻底不打
hilog.info(DOMAIN, 'auth', 'token=%{private}s', token);

// ✅ 更好：脱敏后再打（即使 buildMode=debug 也能看出大致结构）
function masked(s: string): string {
  if (s.length <= 8) return '***';
  return s.slice(0, 4) + '***' + s.slice(-4);
}
hilog.info(DOMAIN, 'auth', 'token=%{public}s', masked(token));
```

```json5
// build-profile.json5 · release 必启用混淆 + log 剥离
{
  "buildOption": {
    "arkOptions": {
      "obfuscation": {
        "ruleOptions": {
          "enable": true,
          "files": ["./obfuscation-rules.txt"]
        }
      }
    }
  }
}
```

```
// obfuscation-rules.txt · 剥离所有 console + 保留 hilog
-disable-obfuscation false
-enable-property-obfuscation
-enable-string-property-obfuscation
-keep-property-name console
-remove-log-statements console.log,console.info,console.debug
```

### `AGC-RJ-008` 误导性广告 / 暗黑模式

- 广告位不能伪装成 UI 控件
- 不能"必须看广告才能用"（除非声明为广告应用）
- 弹窗关闭按钮必须 ≥ 24×24 dp，且与广告内容颜色对比清晰
- 修复：广告位需明确标"广告"二字；关闭键合规化

### `AGC-RJ-009` 后台执行权限滥用

- 后台定位、后台播放、后台运行任务必须有**用户可见的前台通知**
- 不能"sleep 后还在抓数据"
- 修复：用 `@kit.BackgroundTasksKit` 的 `continuousTask` 注册前台服务

**最小代码片段**（后台音乐播放 + 前台通知）：

```typescript
// entry/src/main/ets/entryability/EntryAbility.ets
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

async function startMusicBackgroundTask(ctx: common.UIAbilityContext): Promise<void> {
  // 1. 准备点击通知后跳回的 WantAgent
  const wa = await wantAgent.getWantAgent({
    wants: [{
      bundleName: ctx.abilityInfo.bundleName,
      abilityName: ctx.abilityInfo.name,
    }],
    requestCode: 0,
    actionType: wantAgent.OperationType.START_ABILITY,
  });

  // 2. 注册长时任务（音频类型）—— 这一步会触发前台通知，用户能看到
  try {
    await backgroundTaskManager.startBackgroundRunning(
      ctx,
      backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
      wa,
    );
  } catch (e) {
    const err = e as BusinessError;
    hilog.error(0xBEEF, 'BG', 'start failed: %{public}s', err.message);
  }
}

// 用户停止播放时必须调
async function stopMusicBackgroundTask(ctx: common.UIAbilityContext): Promise<void> {
  await backgroundTaskManager.stopBackgroundRunning(ctx);
}
```

> ⚠️ `module.json5` 还要在 `abilities[].backgroundModes` 声明 `audioPlayback`；漏掉这步会被拒。

### `AGC-RJ-010` 跨境数据 / 第三方 SDK 未声明

- 接入百度地图、友盟、Bugly 等都要在隐私政策中声明
- 数据流向境外服务器需要明确告知用户
- 修复：列清楚每个第三方 SDK 收集什么数据、传到哪里

## 中频拒因（11-20）

### `AGC-RJ-011` 应用名 / 描述违规

- 不能含 "鸿蒙官方"、"华为官方"
- 描述不能与实际功能不符
- 修复：用准确、克制的描述

### `AGC-RJ-012` 内购 / 支付未走 IAP

- 数字商品销售必须用华为 IAP（@kit.IAPKit），抽成 30%（小额 15%）
- 实物销售可以用第三方支付
- 修复：数字商品改 IAP

### `AGC-RJ-013` UI 布局适配错乱

- 折叠屏未适配横竖屏切换
- 平板布局未做断点适配
- 修复：用 `@ohos.mediaquery` + `BreakpointSystem` 做响应式

### `AGC-RJ-014` 国际化字符串硬编码

- 中文写死在 `.ets` 里，未走 `resources/base/element/string.json` + `$r('app.string.xxx')`
- 修复：迁移所有 UI 文案到 string.json

### `AGC-RJ-015` 包大小过大

- 单 HAP 推荐 < 200 MB；超过 1 GB 严重影响审核通过率
- 修复：大资源走 HSP 动态加载或后端下载；图片用 WebP / 矢量图

### `AGC-RJ-016` 未适配深色模式

- 强制用户跟随系统主题
- 没有深色模式视为体验问题（不一定拒，但影响评分）
- 修复：用 `$r('sys.color.ohos_id_color_*')` 系统色

### `AGC-RJ-017` 启动速度慢

- 冷启动 > 2 秒拒
- 修复：用 Profiler 分析；首屏数据用占位 + 异步填充；非必要逻辑放 `aboutToAppear` 之后

### `AGC-RJ-018` 网络异常处理缺失

- 网络断开时没有 UI 提示
- API 失败后无重试 / 兜底
- 修复：所有 `http.request` 都要有 catch + UI 反馈

**最小代码片段**（监听网络状态 + 失败重试 + UI 反馈）：

```typescript
import { connection } from '@kit.NetworkKit';
import { http } from '@kit.NetworkKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

// 监听网络变化
const netCon = connection.createNetConnection();
netCon.register(() => {});
netCon.on('netLost', () => {
  promptAction.showToast({ message: '网络已断开，请检查连接' });
});
netCon.on('netAvailable', () => {
  // 自动重试上次失败请求
});

// 失败重试 + 退避
async function fetchWithRetry<T>(url: string, retries = 3): Promise<T | null> {
  for (let i = 0; i < retries; i++) {
    try {
      const req = http.createHttp();
      const resp = await req.request(url, { connectTimeout: 5000 });
      req.destroy();
      if (resp.responseCode === 200) return JSON.parse(resp.result as string) as T;
    } catch (e) {
      const err = e as BusinessError;
      if (i === retries - 1) {
        promptAction.showToast({ message: `加载失败：${err.message}` });
        return null;
      }
      // 指数退避：1s / 2s / 4s
      await new Promise(r => setTimeout(r, 1000 * Math.pow(2, i)));
    }
  }
  return null;
}
```

### `AGC-RJ-019` 卸载残留

- 卸载后还有数据残留（Preferences / RDB / 文件）
- 修复：默认数据走 sandbox（`getContext().filesDir`），系统会随卸载清理；不要硬写绝对路径

### `AGC-RJ-020` 版本号管理混乱

- `versionCode` 必须严格递增
- `versionName` 不能含中文 / 特殊字符
- 同一 versionCode 不能重复提交
- 修复：用 `versionCode = major * 10000 + minor * 100 + patch` 自动生成

---

## 提审前自查命令

```bash
# 1. 包大小
ls -lh entry/build/default/outputs/default/*.hap

# 2. 权限清单
grep -A 20 '"requestPermissions"' entry/src/main/module.json5

# 3. 硬编码中文（应该几乎没有）
grep -rn "'[一-鿿]" entry/src/main/ets/ | head -20

# 4. console 日志（release 必须 0）
grep -rn 'console\.' entry/src/main/ets/

# 5. 三方 SDK 清单
grep -A 50 '"dependencies"' oh-package.json5 entry/oh-package.json5

# 6. 跑钩子全扫
find entry/src/main/ets -name '*.ets' -exec bash tools/hooks/lib/scan-arkts.sh {} \;

# 7. 包名校验
bash tools/check-ohpm-deps.sh

# 8. 真编译期 lint
bash tools/run-linter.sh --strict
```

---

## 拒因申诉

被拒后：

1. AGC 后台 → 我的应用 → 审核记录 → 拒绝详情
2. 如果是误判：附上具体证据（截图 / 视频 / 日志），点"申诉"
3. 一般 1-2 工作日有人工复审
4. 重复被拒 3 次：建议联系 [开发者支持](https://developer.huawei.com/consumer/cn/support/)

---

## 维护说明

本清单基于 2026-05 阶段调研，AGC 审核标准每季度可能微调。建议：

- 每次有应用被拒，把拒因摘录补到本清单
- 每季度从 [AGC 官方审核标准](https://developer.huawei.com/consumer/cn/doc/distribution/app/agc-help-checkdevelop-0000001146642468) 同步一遍
- 重大版本（如 HarmonyOS 7）发布后 1 个月内重审本清单
