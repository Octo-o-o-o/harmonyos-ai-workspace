---
name: harmonyos-build-debug
verified_against: harmonyos-6.0.2-api22  # last sync 2026-05-07
description: |
  HarmonyOS Hvigor / OHPM / hdc 工具链 + 错误码诊断。
  **激活条件**（满足任一即激活）：
    - 用户跑 hvigorw / ohpm / hdc 命令时出错
    - 用户问构建产物（.hap / .app / .har / .hsp）的差异 / 选型
    - 错误码 201 / 202 / 401 / 801 / 9568305 / 9568322 等鸿蒙特定数字
    - hilog 日志解读 / hdc fport 端口转发 / NAPI 调试
    - 装包到模拟器或真机失败
  **不激活**：Android adb / iOS Xcode / Web devtools 调试问题（即使概念相似）。
---

# HarmonyOS 构建与调试

> 触发场景：构建打包、依赖管理、设备调试、错误诊断、CI/CD。

## 三种产物

| 后缀 | 用途 | 命令 |
| --- | --- | --- |
| `.hap` | 单 module 应用包 | `hvigorw assembleHap` |
| `.app` | 多 hap 上架包（**应用市场必须用**） | `hvigorw assembleApp` |
| `.har` | 静态库（编译期分发） | 在 har module 上 build |
| `.hsp` | 共享库（运行时加载） | 同 har 流程，配置不同 |

## Hvigor 命令

```bash
hvigorw clean                                      # 清干净
hvigorw codeLinter                                 # ArkTS 规则强校验（写完代码必跑）
hvigorw assembleHap -p buildMode=debug             # 编译 debug HAP
hvigorw assembleHap -p buildMode=release           # 编译 release HAP
hvigorw assembleApp -p buildMode=release           # 上架包（含签名参数见下）
hvigorw -p product=default ...                     # 多 product 选择
```

## OHPM 依赖

```bash
ohpm install                                       # 同步 oh-package.json5
ohpm config set registry https://ohpm.openharmony.cn/ohpm/    # 国内镜像
ohpm search <pkg>                                  # 搜包（也可上 https://ohpm.openharmony.cn/）
```

> ⚠️ **AI 经常虚构 OHPM 包名**（特别是 `@ohos/xxx` 前缀）。**先在 https://ohpm.openharmony.cn 搜证**再写 import。

## hdc 设备命令

```bash
hdc list targets                                   # 列设备
hdc -t <id> install -r entry/build/default/outputs/default/*.hap   # 安装
hdc -t <id> uninstall com.example.x                # 卸载
hdc shell aa start -a EntryAbility -b com.example.x   # 启动 Ability
hdc shell                                          # 进入 shell
hdc hilog | grep MyTag                             # 查日志
hdc fport tcp:9229 tcp:9229                        # 端口转发（NAPI / Web 调试）
hdc file send <local> <device-path>                # 推文件
```

## hilog 正确写法

```typescript
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xBEEF;   // 自分配 0x0000–0xFFFF
hilog.info(DOMAIN, 'MyTag', '%{public}s value=%{public}d', name, n);
//                          ^^^^^^^^^ 必须 %{public}，否则被脱敏成 <private>
```

## 常见错误码

| code | 含义 | 立刻检查 |
| --- | --- | --- |
| 201 | PERMISSION_DENIED | `module.json5` + 运行时申请 |
| 202 | 非系统应用 | 该 API 受限；换思路 |
| 401 | 参数错误 | 比对 `upstream-docs/.../reference/` 中签名 |
| 801 | 设备不支持 | `canIUse('SystemCapability.X')` 守护 |
| 16000050 | Ability 启动失败 | `module.json5` abilities 配置 |
| 9568305 | HAP 安装失败 | clean / 包过大 / 签名不一致 |
| 9568322 | 签名校验失败 | profile 与 cert 不匹配 |

## 签名三件套

| 后缀 | 用途 |
| --- | --- |
| `.p12` | 私钥 |
| `.cer` | 证书 |
| `.p7b` | Provision Profile |

调试和发布是两套，不能混用。详见 `signing-publish` skill 与 `00-getting-started/04-signing-and-publishing.md`。

## release 构建命令

```bash
hvigorw clean
ohpm install
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

## CI 注意

- GitHub-hosted Linux runner 可以构建 OpenHarmony，但**不能签名 HarmonyOS 商业 HAP**（需 Huawei SDK + macOS/Windows）
- 上架包必须用 **self-hosted macOS runner**（与 DevEco 同环境）
- 缓存 `~/.ohpm` 和 `oh_modules/` 显著提速

## 终端 hvigorw 的环境变量 · 必跑 sanity check（v0.5 实战补充）

DevEco IDE 内 hvigorw 自动注入环境变量；终端跑必须自己设。**典型崩溃**：

```
00303217 Configuration Error
Error Message: Invalid value of 'DEVECO_SDK_HOME' in the system environment path.
```

**5 个必设环境变量**：

```bash
# macOS / Linux：写到 ~/.zshrc 一劳永逸
cat >> ~/.zshrc <<'ENV'
export DEVECO_SDK_HOME=$HOME/Library/Huawei/Sdk
export PATH=$DEVECO_SDK_HOME/HarmonyOS-NEXT-DB1/openharmony/toolchains/ohpm/bin:$PATH
export PATH=$DEVECO_SDK_HOME/HarmonyOS-NEXT-DB1/openharmony/toolchains:$PATH
# JAVA_HOME 鸿蒙 6 hvigor 默认走 IDE 内置 JBR，但 release 签名时若用外部 JDK 必须设
# export JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home
ENV
source ~/.zshrc
```

### Sanity check（开新 shell 时跑一次）

```bash
echo "DEVECO_SDK_HOME = $DEVECO_SDK_HOME"
which hvigorw && hvigorw --version
which ohpm    && ohpm --version
which hdc     && hdc --version
```

任何一项 not found / Invalid value → 重跑 `bash tools/install-deveco-prereqs.sh` 或 `source ~/.zshrc`。

> `tools/install-deveco-prereqs.sh` 第 6 节会自动配；`tools/run-linter.sh` 也会自动定位 SDK；`tools/verify-environment.sh` 给详细诊断。

## OHPM 仓库 502 兜底（v0.4 实战补充）

`ohpm install` 偶发 502 时：

1. **临时注释非阻塞 devDependencies**（如 hammertest）让 build 通过
2. 切镜像：`ohpm config set registry https://ohpm.openharmony.cn/ohpm/`
3. 走本地缓存：`ohpm install --offline`
4. 实在不通：直接 `hvigorw assembleHap`（已装的依赖仍可用）

## 多模块工程改名 · 三处必须同步

详见 [`runtime-pitfalls`](../runtime-pitfalls/SKILL.md) § 三 + `tools/check-rename-module.sh` 自动校验。

## 进一步参考

- 完整指南：`04-build-debug-tools/README.md`
- 调试技巧：`CLAUDE.md` 第 12 节
- 上架流程：`07-publishing/README.md`
