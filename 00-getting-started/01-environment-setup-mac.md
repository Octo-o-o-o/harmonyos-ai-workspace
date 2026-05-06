# macOS 环境搭建（Apple Silicon）

适用于：macOS 13+（含 macOS 26.x），M1/M2/M3/M4 Apple Silicon 与 Intel Mac。

## 1. 系统要求

| 项目 | 要求 |
| --- | --- |
| OS | macOS 12 (Monterey) 及以上；推荐 13+ |
| CPU | Apple Silicon (推荐) 或 Intel x86_64 |
| 内存 | 8 GB 最低，**16 GB 推荐**（IDE + 模拟器同时启动会用到 12 GB+） |
| 磁盘 | 至少 30 GB 可用（IDE + SDK + 模拟器镜像） |
| 显示器 | 1280×800 最低，推荐 1920×1080+ |
| 网络 | 首次启动需联网拉取 SDK；可配置离线包 |

## 2. 必备工具版本

DevEco Studio 6.x **自带** 以下组件，**通常不需要单独安装**：

- JBR（JetBrains Runtime，相当于 OpenJDK 17）
- Node.js 18.20.x（IDE 内置）
- Hvigor（构建工具，类似 Gradle）
- OHPM（包管理器，类似 npm）
- HarmonyOS SDK（API 12 - 20）
- 模拟器与 hdc

如果你想在 **终端** 里独立运行 hdc / ohpm / hvigor，需要把它们加入 `PATH`（见 §5）。

可选：系统层 Node 22 用于通用脚本与 npm 工具，与 IDE 内置版本互不影响。

## 3. 安装顺序

```
[1] Homebrew  (你已经有了)
       ↓
[2] Node.js (可选，系统层 22) — 你已经有了
       ↓
[3] Git (你已经有了)
       ↓
[4] DevEco Studio       ← 安装包从华为开发者官网下载
       ↓
[5] 首次启动配置向导     ← 自动下载 SDK / Node / Ohpm
       ↓
[6] 把 hdc 加入 PATH
       ↓
[7] (可选) 申请调试签名
```

## 4. DevEco Studio 安装

详见 [`02-deveco-studio-install.md`](02-deveco-studio-install.md)。要点：

1. 访问 <https://developer.huawei.com/consumer/cn/deveco-studio/>
2. 下载 **macOS (arm64)** 版本（Apple Silicon）；Intel Mac 选 x86_64 版本
3. 双击 `.dmg`，拖入 `Applications`
4. 首次启动按提示让 IDE 自动下载 SDK / Node / Ohpm（约 3-6 GB）
5. 同意 SDK License 后即可创建项目

## 5. 把命令行工具加入 PATH

DevEco 安装后，将以下路径加到 `~/.zshrc`：

```bash
# HarmonyOS DevEco Studio 命令行工具
export DEVECO_HOME="/Applications/DevEco-Studio.app/Contents"
export PATH="$DEVECO_HOME/tools/ohpm/bin:$PATH"
export PATH="$DEVECO_HOME/tools/hvigor/bin:$PATH"
export PATH="$DEVECO_HOME/tools/node/bin:$PATH"

# hdc 路径会随 SDK 版本变化，先用通配再固定。常见路径：
# $DEVECO_HOME/sdk/default/openharmony/toolchains
# 或 $HOME/Library/Huawei/Sdk/HarmonyOS-NEXT-DBx/<api>/toolchains
# 安装完 SDK 后用 `find` 定位实际位置：
#   find /Applications/DevEco-Studio.app -name hdc -type f 2>/dev/null
#   find $HOME/Library/Huawei -name hdc -type f 2>/dev/null

# 找到后按实际路径替换：
# export PATH="$HOME/Library/Huawei/Sdk/HarmonyOS-NEXT/openharmony/toolchains:$PATH"
```

加载：

```bash
source ~/.zshrc
hdc version    # 验证
ohpm --version
hvigorw --version
```

## 6. 镜像加速（中国大陆用户建议）

OHPM 默认源在国内速度可能较慢。配置：

```bash
ohpm config set registry https://ohpm.openharmony.cn/ohpm/
ohpm config get registry
```

如果用了代理，再配：

```bash
ohpm config set proxy http://127.0.0.1:7890
ohpm config set https-proxy http://127.0.0.1:7890
```

## 7. 验证清单

```bash
# 系统层
node --version       # 22.x（系统）或 18.20.x（IDE 用）
git --version
brew --version

# DevEco 工具链（加 PATH 后）
hdc version
ohpm --version
hvigorw --version

# DevEco Studio 本体
open -a "DevEco-Studio"
```

成功标志：

- IDE 启动后能在 **Tools → SDK Manager** 看到至少一个已安装的 API（推荐 API 14+）
- 终端中四个命令都返回版本号
- 创建一个 Empty Ability 项目可以正常构建并启动模拟器

## 8. 常见问题

**Q：DevEco Studio 启动报 "Java command failed"？**
A：通常是 PATH 中混入了别的 Java（系统层 JDK 或 SDKMAN）。在 `~/.zshrc` 注释掉 `JAVA_HOME` 与多余的 `PATH` 后重启。DevEco 自带 JBR，不需要外部 JDK。

**Q：模拟器启动失败，黑屏或 "Failed to start emulator"？**
A：检查 macOS Privacy 设置允许 DevEco 访问 Hypervisor；M 系列芯片需要 macOS 12+。重启 IDE 后再试。

**Q：OHPM 报 SSL 错误 / 证书过期？**
A：`ohpm config set strict-ssl false` 临时绕过，并升级 IDE 到 6.0+。

**Q：能不能完全不装 DevEco Studio，只用 CLI？**
A：可以，但需要单独下载 SDK 包并手动配置 hvigor / ohpm 环境，文档见 `04-build-debug-tools/01-cli-only-setup.md`（高级场景）。

## 9. 后续步骤

- [02-deveco-studio-install.md](02-deveco-studio-install.md)：DevEco Studio 安装详细步骤
- [03-first-project.md](03-first-project.md)：创建第一个 HelloWorld
- [04-signing-and-publishing.md](04-signing-and-publishing.md)：签名、调试证书与上架
