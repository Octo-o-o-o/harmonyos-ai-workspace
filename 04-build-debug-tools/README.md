# 构建与调试工具链

HarmonyOS 项目的工具链：

- **Hvigor**：构建工具（类似 Gradle），命令是 `hvigorw`（wrapper）
- **OHPM**：包管理（类似 npm）
- **hdc**：设备连接工具（类似 adb）
- **DevEco Studio**：IDE
- **DevEco Profiler**：性能分析
- **Inspector**：UI 树调试

## 1. Hvigor

### 常用命令

```bash
cd <project-root>

# 同步依赖
hvigorw --sync

# 清理
hvigorw clean

# 构建 debug HAP
hvigorw assembleHap --mode module -p product=default -p buildMode=debug

# 构建 release App（需要签名）
hvigorw assembleApp --mode project -p product=default -p buildMode=release

# 列出所有任务
hvigorw tasks --all

# 单跑某个 module 的某个任务
hvigorw :entry:assembleHap
```

### 关键配置文件

- `hvigorfile.ts`（工程级）：定义构建插件
- `hvigorfile.ts`（模块级）：自定义任务、引入 plugin
- `build-profile.json5`（工程级）：targets / signing / 多渠道
- `build-profile.json5`（模块级）：source set / runtimeOS / targets
- `oh-package.json5`：依赖列表

### 多渠道 / 多 target

`build-profile.json5`（工程级）：

```json5
{
  "app": {
    "products": [
      { "name": "default", "signingConfig": "default" },
      { "name": "premium", "signingConfig": "default" }
    ]
  },
  "modules": [
    {
      "name": "entry",
      "srcPath": "./entry",
      "targets": [
        { "name": "default", "applyToProducts": ["default", "premium"] }
      ]
    }
  ]
}
```

## 2. OHPM

### 全局配置

```bash
ohpm config set registry https://ohpm.openharmony.cn/ohpm/
ohpm config set proxy http://127.0.0.1:7890     # 可选
ohpm config get registry
```

### 项目操作

```bash
ohpm install                                    # 安装所有依赖
ohpm install <package>                          # 添加运行时依赖
ohpm install --save-dev <package>               # 开发依赖
ohpm uninstall <package>
ohpm update [package]
ohpm list
ohpm publish                                    # 发布到私有 / 公共仓库
```

### oh-package.json5

```json5
{
  "modelVersion": "5.0.0",
  "name": "myapp",
  "version": "1.0.0",
  "description": "Demo",
  "main": "",
  "author": "",
  "license": "Apache-2.0",
  "dependencies": {
    "@ohos/axios": "^2.2.5"
  },
  "devDependencies": {}
}
```

### 与 npm 差异

- **不会** 自动 `npm install` —— 需要执行 `ohpm install`，或在 IDE 中点 "Sync Now"
- 包后缀：`.har`（与 Java jar 类似的归档），不是 tarball
- 私有仓库：`ohpm config set @scope:registry https://...`

## 3. hdc

`hdc`（HarmonyOS Device Connector）是主要的设备调试工具。

### 路径

DevEco 安装后位于：
```
~/Library/Huawei/Sdk/HarmonyOS-NEXT-DBx/<api>/openharmony/toolchains/hdc
# 或
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
```

加入 PATH：

```bash
export PATH="$HOME/Library/Huawei/Sdk/HarmonyOS-NEXT-DBx/openharmony/toolchains:$PATH"
```

### 设备列表

```bash
hdc list targets         # 列出连接的设备
hdc list targets -v      # 详细信息
hdc -t <device-id> ...   # 指定设备
```

### 安装 / 卸载 / 启动

```bash
hdc install path/to/app.hap
hdc install -r path/to/app.hap                    # 强制覆盖
hdc uninstall com.example.demo
hdc shell aa start -a EntryAbility -b com.example.demo
hdc shell aa force-stop com.example.demo
hdc shell aa dump -a                               # 列出运行的 abilities
```

### 文件传输

```bash
hdc file send local.txt /data/local/tmp/
hdc file recv /data/log/hilog/log.txt ./
```

### 日志

```bash
hdc hilog                       # 全量
hdc hilog | grep mytag          # 过滤
hdc hilog -T 200                # 最近 200 行
hdc hilog -r                    # 清空缓冲
hdc hilog -L D|I|W|E|F          # 级别过滤
```

### Shell

```bash
hdc shell                       # 进交互 shell
hdc shell ps -A | grep entry   # 列进程
hdc shell df -h                 # 磁盘
hdc shell ls /data/storage/el2/base/haps/<bundle>/files
```

### 端口转发

```bash
hdc fport tcp:9229 tcp:9229     # PC 9229 → device 9229，调试 NodeJS / NAPI
hdc fport ls
hdc fport rm tcp:9229
```

### 截屏 / 录屏

```bash
hdc shell snapshot_display -f /data/local/tmp/screen.png
hdc file recv /data/local/tmp/screen.png ./
```

## 4. DevEco Studio Inspector & Profiler

### Inspector（UI 调试）

- **View → Tool Windows → ArkUI Inspector**
- 实时查看组件树、属性、布局边界
- 选中组件可在编辑器内反向定位到 ets 源码
- 支持元素吸取（点击设备 UI 后高亮对应节点）

### Profiler（性能）

- **View → Tool Windows → Profiler**
- CPU / Memory / Network / Frame
- Frame 视图能看每帧渲染耗时，识别掉帧
- 录制后支持火焰图（FlameGraph）分析

### Code Linter

- **Code → Inspect Code** 或运行 `hvigorw codeLinter`
- 默认规则在 `code-linter.json5`，可自定义

## 5. 模拟器命令行（可选）

```bash
# 列出可用模拟器
ls ~/Library/Huawei/HarmonyOSDeviceEmulator/

# 启动模拟器（通过 IDE 更方便）
# 命令行启动需要 OpenHarmony QEMU，详见
# upstream-docs/.../tools/
```

## 6. CLI-only 工作流（不开 IDE）

适合 CI / 远程构建：

```bash
# 1. 设置环境
export DEVECO_HOME=/Applications/DevEco-Studio.app/Contents
export PATH=$DEVECO_HOME/tools/ohpm/bin:$DEVECO_HOME/tools/hvigor/bin:$DEVECO_HOME/tools/node/bin:$PATH

# 2. 同步依赖
cd <project>
ohpm install

# 3. 构建
hvigorw clean
hvigorw assembleHap -p buildMode=release \
  -p storeFile=/path/my.p12 \
  -p storePassword=$KEY_PASS \
  -p keyAlias=myalias \
  -p keyPassword=$KEY_PASS \
  -p signAlg=SHA256withECDSA \
  -p profile=/path/profile.p7b \
  -p certpath=/path/cert.cer

# 4. 安装
hdc install ./entry/build/default/outputs/default/entry-default-signed.hap
```

## 7. 故障排查

| 现象 | 排查 |
| --- | --- |
| `hdc list targets` 看不到设备 | 启用 USB 调试；MacOS Privacy → USB 允许；换数据线 |
| Hvigor 卡在 `Resolving Dependencies` | 删 `oh_modules`、`.hvigor`，重 sync |
| OHPM SSL 错误 | `ohpm config set strict-ssl false` 临时绕过 |
| 模拟器启动失败 | 重启 IDE；检查 macOS 是否启用 Hypervisor |
| HAP 安装报 9568305 | 包体过大或 abc 文件未编译，clean 后重建 |
| ECCN: 9568322 | 签名 / profile 不匹配，重新生成签名 |

## 8. 参考

- Hvigor 官方：`upstream-docs/.../tools/hvigor/`
- OHPM 官方：`upstream-docs/.../tools/ohpm-tool.md`
- hdc 详解：`upstream-docs/.../tools/hdc.md`
- DevEco 工具：`upstream-docs/.../tools/`
