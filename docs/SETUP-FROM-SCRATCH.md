# 从零到 Hello HarmonyOS · 完整引导

> 给**完全没装过鸿蒙开发环境**的开发者。读完这一篇，能从 macOS 干净状态走到"AI 在 Claude Code 里写鸿蒙代码 + 钩子自动校验"。
>
> 一句话总结：**`bash tools/setup-from-scratch.sh` 一行启动半自动向导**。本文档解释每一步在做什么、卡住怎么办。

---

## 0. 先确认你需要的是什么

| 你的状态 | 直接看哪段 |
| --- | --- |
| macOS 干净，啥都没装 | § 1 → § 2 → § 3 → § 4 → § 5 |
| DevEco 装了但没装 Claude Code | § 4 → § 5 |
| Claude Code 装了但还没装本仓库规则 | § 5（一行 curl） |
| 都装好了，想跑 hello world | § 6 |
| 想绕开向导，全手动 | § 7 |

**预计耗时**：干净状态到第一行 `.ets` 跑通 = **30-60 分钟**（其中 SDK 下载 5-30 分钟取决于网速）。

---

## 1. 系统前置（macOS Apple Silicon / Intel）

需要提前有：

- macOS 12.0+
- 至少 30 GB 可用磁盘（DevEco ~1.6 GB + SDK ~6 GB + 模拟器 ~3 GB + 你的项目 / 缓存）
- 16 GB 内存（8 GB 跑得动但模拟器会卡）
- 网络（首次下载 SDK 需要稳定连接，国内建议配镜像）

如果你已经在做前端 / 后端开发，常见基础工具一般已就位。本仓库 `tools/install-deveco-prereqs.sh` 会自动检查并装：

- **Homebrew**（macOS 包管理）
- **git**
- **Node.js**（DevEco 内置 Node 18.20，但系统级也建议有）
- **HarmonyOS Sans 字体**（可选，UI 实机效果对齐）

```bash
git clone https://github.com/Octo-o-o-o/harmonyos-ai-workspace.git ~/WorkSpace/HarmonyOS_DevSpace
cd ~/WorkSpace/HarmonyOS_DevSpace

# 全自动装基础工具（幂等，可反复跑）
bash tools/install-deveco-prereqs.sh
```

> ⚠️ 第一次跑会触发 Homebrew 自身的安装脚本（远端 curl），需要 sudo 输密码。这一步无法绕过——Homebrew 是绝大多数 macOS 开发的基础。

---

## 2. DevEco Studio（必装，但不能自动装）

**为什么不能自动装**：DevEco 官方下载页要求登录华为账号，账号校验后才给 DMG 链接。脚本绕不过这层政策。

**手动步骤（一次性）**：

1. 打开 <https://developer.huawei.com/consumer/cn/deveco-studio/>
2. 没有华为账号 → 注册：<https://id.huawei.com>
3. 登录后选最新稳定版 DevEco Studio（**6.0.x**，对应 HarmonyOS 6 / API 21-22）
4. 选 **macOS (ARM)**（M1/M2/M3/M4）或 **(X86)**（Intel）
5. 下载 ~1.6 GB 的 `.dmg`
6. 双击 DMG → 把 `DevEco-Studio` 拖到 `Applications`
7. 第一次启动会被 macOS Gatekeeper 拦截：
   **系统设置 → 隐私与安全 → "DevEco-Studio 已被阻止" → 仍要打开**
8. 进入首次启动向导：
   - **Node.js**：选 "Install"（让 IDE 装内置 18.20，避免冲突）
   - **Ohpm**：选 "Install"
   - **SDK**：勾 **API 21**（消费稳定）+ **API 22**（最新）+ 一个 LTS（如 API 12）
   - 同意 License → 等 SDK 下载（5-30 分钟）

**镜像加速**（国内）：在 IDE **Help → Edit Custom Properties** 加：

```properties
huawei.sdk.repository=https://mirrors.tuna.tsinghua.edu.cn/openharmony/sdk/
```

---

## 3. PATH 配置（脚本自动）

DevEco 装完不会自动把 `hdc` / `ohpm` / `hvigorw` 加到 PATH。本仓库脚本会检测 SDK 路径并自动写到 `~/.zshrc`：

```bash
bash tools/install-deveco-prereqs.sh   # 已跑过的话再跑一遍是幂等的
source ~/.zshrc                         # 立即生效
```

验证：

```bash
which hdc ohpm hvigorw
# 三条都应该输出绝对路径
```

---

## 4. 装 Claude Code（或 Codex CLI）

本仓库不是独立工具，是 AI 编码助手的"鸿蒙领域规则包"。装一个 AI 助手才能用：

```bash
# 推荐：Claude Code
npm i -g @anthropic-ai/claude-code

# 或者：Codex CLI
brew install codex
# 或 npm i -g @openai/codex

# 都装也可以
```

验证：

```bash
claude --version
codex --version       # 装了再查
```

---

## 5. 装本仓库规则到你的鸿蒙 app

**前置**：你需要有一个鸿蒙 app 项目目录。如果还没有：

1. 打开 DevEco Studio
2. **File → New → Create Project**
3. 选 **Application → Empty Ability**
4. 配置：
   - Project name: `MyFirstApp`
   - Bundle name: `com.example.myfirstapp`
   - Save location: `~/WorkSpace/apps/my-first-app/`
   - Compile SDK: **API 21** 或 **22**
   - Model: **Stage**（FA 已废弃）
   - Language: **ArkTS**
5. 点 Finish 等 Hvigor sync 完

然后回到终端：

```bash
cd ~/WorkSpace/apps/my-first-app
curl -fsSL https://raw.githubusercontent.com/Octo-o-o-o/harmonyos-ai-workspace/main/tools/install.sh | bash
```

这会装：

- `CLAUDE.md` / `AGENTS.md`（AI 规则）
- `.claude/settings.json`（PostToolUse 钩子）
- `.claude/skills/` 5 个按需触发的 Skills
- `tools/hooks/`（钩子脚本）
- `tools/check-ohpm-deps.sh`（OHPM 包名校验）
- `.mcp.json`（MCP 配置）

**装完立即自测**（验证钩子工作）：

```bash
cat > /tmp/_test.ets <<'EOF'
@Entry @Component struct X {
  @State items: number[] = [];
  build() { Button('+').onClick(() => { this.items.push(1) }) }
}
EOF
echo '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/_test.ets"}}' | bash tools/hooks/post-edit.sh
rm /tmp/_test.ets
```

预期输出：`[STATE-002 · High] /tmp/_test.ets:3: ... 数组就地 mutation 不触发重渲染`。看到这条 = 钩子工作。

---

## 6. 启动 AI，开始写代码

```bash
cd ~/WorkSpace/apps/my-first-app
claude       # 或 codex
```

第一次让它做什么？建议：

```
> 帮我加一个简单的待办列表页面：用 LazyForEach 显示一组 string，加按钮新增条目。
```

AI 写完文件后，钩子会自动跑，命中反模式则在 stderr 输出，AI 看到后会自我修正。**这就是本仓库的核心价值**。

---

## 7. 一键串联（推荐）

上面 § 1-5 全部串联好了：

```bash
cd ~/WorkSpace/HarmonyOS_DevSpace
bash tools/setup-from-scratch.sh

# 想自动跳过提示：
bash tools/setup-from-scratch.sh --app-dir=~/WorkSpace/apps/my-first-app -y
```

向导会：

1. 跑 `install-deveco-prereqs.sh` 装基础工具 + 配 PATH
2. 检查 DevEco（未装则打开下载页 + 给步骤）
3. 检查 PATH 工具链
4. 装 Claude Code（npm 一键）
5. 你输入 app 路径，到该路径跑 `install.sh`
6. 跑钩子自测
7. 给最终 cheat sheet

---

## 8. 校验环境

任何阶段都可以跑：

```bash
bash tools/verify-environment.sh
```

输出每项检查 + 失败项的"下一步建议"。

---

## 9. 常见问题

### Q：DevEco 下载特别慢

走清华镜像在 IDE 内（前面 § 2 末尾），或者用迅雷下 DMG。

### Q：Claude Code 装失败 `EACCES`

`npm config get prefix` 看看；如果是系统目录权限不足：

```bash
# 给 npm 全局换个用户目录
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.zshrc
source ~/.zshrc
npm i -g @anthropic-ai/claude-code
```

### Q：钩子跑了但 Claude 没看见反馈

Claude Code 会把 hook 的 stderr 注入下一轮上下文。如果你直接 `bash` 跑钩子是看到的 stderr 输出，但 Claude 用 hook 时却"没反应"——通常是 `.claude/settings.json` 没正确放在 app 项目根。验证：

```bash
cat .claude/settings.json | head -10
# 应当含 "PostToolUse" 与 "tools/hooks/post-edit.sh"
```

### Q：模拟器跑不动

模拟器需要 8 GB+ 内存，建议 16 GB。如果机器吃紧：

- 用真机调试（华为账号申请调试证书；DevEco 自动签名）
- 或用 Profiler 跑 headless：`hvigorw test`

### Q：Windows 怎么办？

本向导 v0.2 仅 macOS。Windows 用户两个选择：

- **WSL2**：`apt install` 装 git/node 等基础，再装 DevEco for Windows + 在 WSL 内跑本仓库的 bash 脚本
- **Native PowerShell**：v0.3 候选，目前手动按本文档 § 1-5 步骤等价操作即可

---

## 10. 完成后的下一步

读这些就够你写第一个 app：

- [`README.md`](../README.md) § 5 分钟自测：复习一遍能跑通
- [`CLAUDE.md`](../CLAUDE.md) § 0 ArkTS 硬约束：写代码前必看
- [`.claude/skills/state-management/SKILL.md`](../.claude/skills/state-management/SKILL.md)：状态管理铁律
- [`07-publishing/checklist-2026-rejection-top20.md`](../07-publishing/checklist-2026-rejection-top20.md)：上架前必看

进阶：

- [`docs/USAGE-GUIDE.md`](USAGE-GUIDE.md)：多 app 共享规则、与同类项目差异化
- [`docs/MCP-INTEGRATION.md`](MCP-INTEGRATION.md)：接入动作型 MCP（AI 直接装设备 / 截图）

---

## 11. 我卡住了

按这个顺序排查：

1. 跑 `bash tools/verify-environment.sh`，看哪一项 fail
2. 看本文档 § 9 常见问题
3. 看 [`README.md` 常见故障排查](../README.md)
4. 在仓库开 issue：<https://github.com/Octo-o-o-o/harmonyos-ai-workspace/issues>

每条 issue 请贴：

- macOS 版本 + Apple Silicon / Intel
- DevEco 版本（`defaults read /Applications/DevEco-Studio.app/Contents/Info CFBundleShortVersionString`）
- `bash tools/verify-environment.sh` 的完整输出
- 你跑的命令 + 报错
