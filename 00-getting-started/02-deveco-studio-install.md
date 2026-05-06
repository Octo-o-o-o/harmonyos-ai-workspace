# DevEco Studio 安装详解（macOS）

DevEco Studio 是华为为 HarmonyOS / OpenHarmony 推出的官方 IDE，基于 IntelliJ Platform，**集成了 SDK / Node / Hvigor / OHPM / 模拟器**。

## 1. 下载

⚠️ **官方下载页要求登录华为账号**（实名认证后），无匿名直链。

1. 打开 <https://developer.huawei.com/consumer/cn/deveco-studio/>
2. 点击「立即下载」，跳转登录页
3. 登录华为账号（没有的话先注册：<https://id.huawei.com>）
4. 在版本列表中选择：
   - **DevEco Studio 6.0.x**（推荐，对应 HarmonyOS 6 系列：API 21 / 6.0.1 稳定版、API 22 / 6.0.2 现行消费版）
   - **macOS (ARM)** —— Apple Silicon (M1/M2/M3/M4)
   - **macOS (X86)** —— Intel Mac
5. 文件名形如：`devecostudio-mac-arm64-6.0.0.xxx.dmg`，约 1.2-1.6 GB

历史版本下载：<https://developer.huawei.com/consumer/cn/deveco-studio/archive/>

> 如果你正在使用本资料库的安装脚本：`tools/install-deveco-prereqs.sh` 会自动检查环境并提示你完成下载与安装。

## 2. 安装

```bash
# 1) 双击 .dmg 文件挂载磁盘镜像
# 2) 把 DevEco-Studio 图标拖到 Applications
# 3) 卸载磁盘镜像
# 4) 首次启动会被 macOS Gatekeeper 拦截：
#    Settings → Privacy & Security → "DevEco-Studio was blocked..." → Open Anyway
```

或终端验证安装：

```bash
ls -la /Applications/DevEco-Studio.app
codesign -dv /Applications/DevEco-Studio.app 2>&1 | head -3
```

## 3. 首次启动向导

启动后会进入「Setup Wizard」：

### 3.1 选择 UI 主题

随个人喜好（Light / Darcula）。

### 3.2 配置 Node.js

向导会询问：
- **Set up Node.js Path**: 选 "Install"，让 IDE 下载内置的 Node 18.20.x（推荐，避免和系统 Node 冲突）
- 或选 "Local"，指向已有的 Node（要求 16.20+ / 18.20+）

### 3.3 配置 Ohpm

同样选 "Install"，让 IDE 自动下载。

### 3.4 配置 SDK

- 默认安装路径：`~/Library/Huawei/Sdk`
- 选择 **API Level 12 ~ 22**，建议至少勾选 API 21（消费稳定版，2025-11-25 首发）+ API 22（最新 6.0.2，2026-01-23 推送）+ 一个长期兼容线（如 API 12 / API 18）
- 勾选 "Native Toolchain"（如果你要写 C/C++ NAPI 模块）
- 同意所有 License

### 3.5 等待下载

约 3-6 GB，视网络快慢需要 5-30 分钟。失败可在 IDE 内 **Tools → SDK Manager** 重试。

## 4. 中国大陆镜像加速

如果下载 SDK 慢，编辑：

```
~/.deveco-studio/idea.properties
```

或在 IDE 的 Help → Edit Custom Properties，加入：

```properties
huawei.sdk.repository=https://mirrors.tuna.tsinghua.edu.cn/openharmony/sdk/
```

> 镜像地址可能变化，参考 [清华开源镜像](https://mirrors.tuna.tsinghua.edu.cn/openharmony/) 与 [华为云镜像](https://mirrors.huaweicloud.com/)。

## 5. 注册插件 / 模拟器

1. **Tools → Device Manager**
2. 点 **+** 创建模拟器：选择 Phone / Tablet 模板，API 选 12 或 20
3. 等待镜像下载（约 1.5 GB），启动验证

## 6. 配置 Apple Silicon 原生运行

DevEco Studio 6.x 已是 universal binary。验证：

```bash
file /Applications/DevEco-Studio.app/Contents/MacOS/devecostudio
# 应显示包含 "arm64" 字样

# 或用 Activity Monitor 查看，"种类" 列应为 "Apple"（不是 "Intel"）
```

如果显示为 Intel，重新下载 ARM 版本。

## 7. 命令行工具暴露

参见 [`01-environment-setup-mac.md`](01-environment-setup-mac.md) §5，把 `ohpm` `hvigor` `hdc` 加入 `~/.zshrc` 的 `PATH`。

## 8. 卸载

```bash
# 1) 删除 App 本体
rm -rf /Applications/DevEco-Studio.app

# 2) 删除用户数据与缓存
rm -rf ~/Library/Application\ Support/Huawei/DevEco-Studio*
rm -rf ~/Library/Caches/Huawei/DevEco-Studio*
rm -rf ~/Library/Logs/Huawei/DevEco-Studio*
rm -rf ~/Library/Preferences/com.huawei.devecostudio*
rm -rf ~/.deveco-studio*

# 3) 删除 SDK
rm -rf ~/Library/Huawei/Sdk

# 4) 删除模拟器镜像
rm -rf ~/Library/Huawei/HarmonyOSDeviceEmulator
```

## 9. 排错

| 现象 | 原因 / 解决 |
| --- | --- |
| IDE 启动闪退 | 在 `~/Library/Logs/Huawei/DevEco-Studio*/idea.log` 看堆栈；多半是 JBR 缺失，重装 |
| Gradle / Hvigor 同步失败 | 删除 `~/.hvigor`、项目下 `.hvigor` 与 `oh_modules`，重新 sync |
| OHPM SSL 错误 | `ohpm config set strict-ssl false`，并把 IDE 升到 6.0.1+ |
| 模拟器无法启动 | macOS 系统设置 → Privacy & Security → 允许 Hypervisor；重启 Mac |
| "无法验证开发者" | `xattr -dr com.apple.quarantine /Applications/DevEco-Studio.app` |

## 10. 参考链接

- 官方安装文档：<https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-software-install>
- 工具下载：<https://developer.huawei.com/consumer/cn/download/deveco-studio>
- 历史版本：<https://developer.huawei.com/consumer/cn/deveco-studio/archive/>
- 论坛求助：<https://developer.huawei.com/consumer/cn/forum/>
- 第三方安装教程（中文）：[CSDN 教程汇总](https://blog.csdn.net/m0_69307756/article/details/135825179)
