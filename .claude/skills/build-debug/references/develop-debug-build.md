# 开发 / 调试 / 构建注意事项（详细版）

> 这份是 build-debug skill 的详细 references。SKILL.md 给入口 + 触发；本文件给完整细节。
>
> 来源：从 CLAUDE.md § 11-13 拆出（保持权威性，但不再每轮注入）。

---

## 一、开发阶段（develop）注意事项

### 1.1 文件后缀语义

| 后缀 | 用途 | AI 易踩 |
| --- | --- | --- |
| `.ets` | 含 UI 组件（`@Component` / `build()`） | 把纯逻辑写到 .ets |
| `.ts` | 纯 ArkTS 逻辑、工具类 | 在 .ts 里写 `@Component` |
| `.d.ts` | 类型声明 | — |
| `.json5` | 配置（app/module/build-profile） | 把 JSON 注释写成 // 但缺逗号 |

### 1.2 Stage 模型硬性约束

- 每个 module 必须有一个 UIAbility，绑定 `WindowStage` 加载页面
- `module.json5` 的 `abilities[i].srcEntry` 必须指向真实 `.ets` 路径
- `AppScope/app.json5` 的 `bundleName` 改了，整个签名链都要重生成
- 添加新 page：除了创建 `.ets`，还要在 `resources/base/profile/main_pages.json` 注册路由表

### 1.3 状态管理坑点（详见 state-management skill）

- 不要在 `build()` 里 `setState` / await / new Date() — `build()` 必须是纯函数
- 数组 / 对象 mutation 不会触发 UI 更新；必须替换整个引用：
  ```typescript
  // ❌ this.list.push(x);
  // ✅ this.list = [...this.list, x];
  ```
- `@Link` 调用方传参写 `$$xxx`，不是 `xxx`
- V2 的 `@Param` 默认不可变；调用方修改要改用 `@Local` 或加 `@Event` 回调

### 1.4 IDE 报红 vs 编译报错

- IDE 实时标红可能是 LSP 滞后；点 **File → Invalidate Caches → Restart** 或 `hvigorw clean` 后再判断
- 真错误以 `hvigorw assembleHap` 输出为准

### 1.5 写完 AI 代码立刻跑

```bash
ohpm install                            # 改了 oh-package.json5
hvigorw codeLinter                      # 检查 ArkTS 规则
hvigorw assembleHap -p buildMode=debug  # 编译验证
```

### 1.6 不允许的依赖来源

- 不要 `import` 任何 `node_modules` 的 npm 包（除非该包同时发布到 OHPM）
- AI 经常推荐 axios / lodash / moment — 在 ArkTS 里改用：
  - axios → `@kit.NetworkKit` 的 `http`
  - lodash → 自写工具或 `@kit.ArkTS` 的 ArrayList / HashMap
  - moment → `@kit.LocalizationKit` 的 `i18n.DateTimeFormat`

---

## 二、调试阶段（debug）注意事项

### 2.1 日志格式必须正确

```typescript
import { hilog } from '@kit.PerformanceAnalysisKit';
hilog.info(0xBEEF, 'MyTag', '%{public}s value=%{public}d', name, n);
```

- DOMAIN：`0x0000-0xFFFF` 自分配
- `%{public}s` 而非 `%s`：`s` 默认会被脱敏成 `<private>`
- 过滤：`hdc hilog | grep MyTag`

### 2.2 ArkUI Inspector 使用流程

1. Run 应用到模拟器或真机
2. **View → Tool Windows → ArkUI Inspector**
3. 选元素吸取（点 IDE 工具栏的小图标，再点设备 UI）
4. 看组件树 / 属性 / 反向定位源码

布局诡异时**先用 Inspector 看，比读代码快**。

### 2.3 Profiler 录制

- **View → Tool Windows → Profiler** → Record
- 关注 Frame 视图找掉帧
- CPU 火焰图找慢函数

### 2.4 真机 vs 模拟器能力差异

| 能力 | 模拟器 | 真机 |
| --- | --- | --- |
| ArkUI / 路由 / 网络 / 文件 / 数据库 | ✅ | ✅ |
| 相机 | 部分 | ✅ |
| 蓝牙 / NFC / Push | ❌ | ✅ |
| 真实 GPS | ❌ mock | ✅ |
| 生物识别 | ❌ | ✅ |
| 多端协同 | 部分 | ✅ |

模拟器调不通的 API 先核对此表，避免误判为代码 bug。

### 2.5 hdc 端口转发用于 NAPI / Web 调试

```bash
hdc fport tcp:9229 tcp:9229            # PC ↔ device
# 然后在 Chrome chrome://inspect 中连
```

### 2.6 常见错误码（必背）

| code | 含义 | 立刻检查 |
| --- | --- | --- |
| 201 | PERMISSION_DENIED | `module.json5` + 运行时申请 |
| 202 | 非系统应用 | 该 API 受限；换思路 |
| 401 | 参数错误 | 比对 `upstream-docs/.../reference/` 中签名 |
| 801 | 设备不支持 | `canIUse('SystemCapability.X')` 守护 |
| 16000050 | Ability 启动失败 | `module.json5` 的 abilities 配置 |
| 9568305 | HAP 安装失败 | clean / 包过大 / 签名不一致 |
| 9568322 | 签名校验失败 | profile 与 cert 不匹配 |

---

## 三、构建与打包阶段（build）注意事项

### 3.1 三种产物

| 后缀 | 用途 | 命令 |
| --- | --- | --- |
| `.hap` | 单 module 包 | `hvigorw assembleHap` |
| `.app` | 上架包（多 hap 合并） | `hvigorw assembleApp` |
| `.har` | 静态库（编译期分发） | 在 module 上 build |
| `.hsp` | 共享库（运行时加载） | 同 har 流程，配置不同 |

**上架华为应用市场必须用 `.app`**。

### 3.2 签名三件套（与 Android 完全不同）

- `.p12` 私钥
- `.cer` 证书
- `.p7b` Provision Profile

调试和发布是两套，不能混用。详见 `signing-publish` skill 与 `00-getting-started/04-signing-and-publishing.md`。

### 3.3 release 构建必跑

```bash
hvigorw clean                                  # 清干净
ohpm install                                   # 同步依赖
hvigorw assembleApp -p buildMode=release \
  -p storeFile=$KEYSTORE_FILE \
  -p storePassword=$KEYSTORE_PWD \
  -p keyAlias=$KEY_ALIAS \
  -p keyPassword=$KEY_PWD \
  -p signAlg=SHA256withECDSA \
  -p profile=$PROFILE_FILE \
  -p certpath=$CERT_FILE
```

签名密码不要硬编码，用环境变量或 CI Secret。

### 3.4 混淆与瘦身

`build-profile.json5`：

```json5
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

不混淆容易被反编译；非业务字段在 `obfuscation-rules.txt` 中 `keep` 防止反射类调用失败。

### 3.5 OHPM 依赖陷阱

- AI 经常虚构包名（特别是 `@ohos/xxx` 前缀）。**先在 <https://ohpm.openharmony.cn/> 搜证**；本仓库 `tools/check-ohpm-deps.sh` 自动校验
- 修改 `oh-package.json5` 后必须 `ohpm install`
- 拉不动时先 `ohpm config set registry https://ohpm.openharmony.cn/ohpm/`

### 3.6 多模块 build 顺序与冲突

- HAR / HSP 必须在依赖它们的 entry 之前编译；IDE 会自动，CI 要确认
- 同名 .so / 同名资源会让最终 .app 缺包；编译时关注 hvigor 的 warning
- 多 product（多渠道）共享同一签名时，bundleName 必须严格一致

### 3.7 包大小红线

- 单 HAP < 4 GB（系统硬限）
- 推荐单 HAP < 200 MB（应用市场审核更友好）
- 大资源走 HSP 动态加载或后端下载
- 启用 WebP / 矢量图取代 PNG

### 3.8 CI 注意事项

- GitHub-hosted runner **不能装 DevEco**（License 限制）；用 self-hosted macOS runner
- License 加速：DevEco 不需要联网激活，但首次启动配置 SDK 需要拉文件
- 缓存：缓存 `~/.ohpm` 与 `oh_modules` 大幅提速
