# HarmonyOS DevSpace

> 让 **Claude Code / Codex CLI / Cursor / Copilot** 写出能编译过的鸿蒙代码。
>
> 基线：裸 LLM 在 ArkTS 上 Pass@1 仅 **3.13%**（[ArkEval](https://arxiv.org/html/2602.08866)）。本仓库通过**规则注入 + Edit 后自动校验 + OHPM 包名核验**把这个数字显著拉高。

## 版本契约（Version Contract）

```yaml
targets:
  harmonyos:      ">= 6.0.0  (API >= 12, 推荐 21/22)"
  arkts:          ">= 1.2.0"
  deveco_studio:  ">= 6.0"
  claude_code:    ">= 0.5"
  codex_cli:      ">= 0.1"
last_verified: "2026-05-07"
```

> 鸿蒙生态快速迭代（API 12 → 22 跨度大）。本仓库每次发版前在 `last_verified` 日期对齐一次"当前消费稳定版"。如果你的 SDK 比这更新，建议先跑 `bash tools/run-linter.sh` 自查规则是否仍适用，并在 issue 里反馈差异。

## 它怎么工作（一图流）

```
┌──────────────────────────────────────────────────────────────────┐
│   你的鸿蒙 app 项目                                              │
│   ┌─────────┐                                                    │
│   │ AI 助手 │  Claude Code / Codex / Cursor / Copilot           │
│   └────┬────┘                                                    │
│        │ 启动时自动加载                                          │
│        ▼                                                          │
│   CLAUDE.md / AGENTS.md / .cursor/rules/ / .github/copilot-…     │
│        │ AI 读到鸿蒙硬约束                                       │
│        ▼                                                          │
│   AI 写代码 → Edit .ets / .ts / oh-package.json5                 │
│        │                                                          │
│        ▼ ⚡ 钩子触发（仅 Claude Code 强校验）                    │
│   ┌─────────────────────────────────────────────────────┐        │
│   │ tools/hooks/post-edit.sh                            │        │
│   │  ├─ scan-arkts.sh   31 条规则 + 装饰器上下文 + 折叠   │        │
│   │  ├─ check-ohpm-deps.sh  OHPM 包名黑/白/CLI 三层     │        │
│   │  └─ module.json5    权限提示                        │        │
│   └─────────────────────────────────────────────────────┘        │
│        │                                                          │
│        ├─ High 级 → exit 2 + stderr   ▶ AI 看到，自我修正        │
│        └─ Medium  → exit 0 + stderr   ▶ AI 看到，但不阻塞        │
│        │                                                          │
│        ▼                                                          │
│   写入 .claude/.harmonyos-last-scan.txt（下一轮 AI 可读）        │
│                                                                   │
│   人类 → hvigorw assembleHap → 设备                              │
└──────────────────────────────────────────────────────────────────┘
```

## 这是给谁用的？

**前置要求**：你必须已经在用以下任意一个 AI 编码助手——本仓库不是独立工具，是给它们装的"鸿蒙领域规则包"。

| AI 工具 | 安装 | 本仓库怎么注入 |
| --- | --- | --- |
| **Claude Code** | `npm i -g @anthropic-ai/claude-code` | `CLAUDE.md` 自动加载 + PostToolUse 钩子 |
| **Codex CLI** | `brew install codex` 或 `npm i -g @openai/codex` | `AGENTS.md` 自动加载 |
| **Cursor** | <https://cursor.com> | `.cursor/rules/harmonyos.mdc` |
| **GitHub Copilot** | VS Code Marketplace | `.github/copilot-instructions.md` |

没装过其中任何一个？或者**完全没装过 DevEco Studio**？看 [`docs/SETUP-FROM-SCRATCH.md`](docs/SETUP-FROM-SCRATCH.md)——从 macOS 干净状态到第一行 `.ets` 跑通的完整引导（30-60 分钟）。或者一行启动半自动向导：

```bash
git clone https://github.com/Octo-o-o-o/harmonyos-ai-workspace.git ~/WorkSpace/HarmonyOS_DevSpace
cd ~/WorkSpace/HarmonyOS_DevSpace
bash tools/setup-from-scratch.sh
```

## 5 秒决策：装到哪里？

```
┌─────────────────────────────────────────────────────────────────┐
│ 我已经有鸿蒙 app 项目，想让 AI 不再写 ArkTS 编译错             │
│   → 用法 A：一行 curl 把规则装进 app（不需要 clone 本仓库)    │
│   → 时间：30 秒                                                 │
│   → 体积：< 1 MB（不含官方文档镜像）                            │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│ 我想离线读完整 OpenHarmony 官方文档 / 系统学鸿蒙 / 给本仓库贡献 │
│   → 用法 B：git clone 整个工作区                                │
│   → 时间：3-10 分钟（视是否拉文档镜像）                         │
│   → 体积：基础 < 5 MB；可选含官方文档镜像 ~2.7 GB              │
└─────────────────────────────────────────────────────────────────┘
```

**99% 的鸿蒙开发者只需要用法 A**。用法 B 是给"想看官方文档原件 / 系统学习 / 维护本仓库"的人。

> **AI 规则文件**：[CLAUDE.md](CLAUDE.md)（Claude Code 自动加载）/ [AGENTS.md](AGENTS.md)（Codex / Cursor / Aider 自动加载）。这两个文件是 AI 行为的硬约束，**人类用户不需要主动读**——AI 工具进入仓库会自己加载。
>
> **仓库地址**：<https://github.com/Octo-o-o-o/harmonyos-ai-workspace>  · fork 维护自己版本时，把命令中的 `Octo-o-o-o` 替换为你的 GitHub 用户名。

---

## 内置内容

- **AI 规则集** · `CLAUDE.md`（Claude）+ `AGENTS.md`（24+ 工具通用）+ 8 个按需触发的 [`.claude/skills/`](.claude/skills/)（含 runtime-pitfalls 工程装配陷阱、multimodal-llm / web-bridge 领域专项）
- **PostToolUse 钩子链路** · Edit `.ets`/`.ts`/`oh-package.json5` 后自动跑 ArkTS 反模式扫描 + OHPM 包名核验 + 权限提示
- **多工具 fan-out** · 单源 `.claude/skills/*/SKILL.md` → Cursor `.mdc` + Copilot instructions
- **CLI 工具集** · `install.sh`（一行装到 app）/ `run-linter.sh`（离线 codeLinter）/ `check-ohpm-deps.sh`（包名校验）/ `setup-from-scratch.sh`（新手向导）/ `bootstrap-upstream-docs.sh`（按需拉文档镜像）
- **2026 提审 Top 20 拒因** · [`07-publishing/checklist-2026-rejection-top20.md`](07-publishing/checklist-2026-rejection-top20.md)，6 条高频项配可粘贴代码片段
- **测试 fixture** · `tools/hooks/test-fixtures/` 9 个回归 fixture（8 故意写错 + 1 应通过 + 反测试用例），覆盖 inline 装饰器 / @CustomDialog / @Reusable / 普通工具类等边界
- **MCP** · `.mcp.json` 接通 `mcp-harmonyos`（npx 自动）；动作型 MCP 接入指引见 [`docs/MCP-INTEGRATION.md`](docs/MCP-INTEGRATION.md)
- **可选官方文档镜像** · 5300+ 中文 + 5100+ 英文 OpenHarmony md（按需 `bootstrap-upstream-docs.sh -y` 拉取，~2.7 GB）
### 真正独有的能力（vs 同类项目）

PostToolUse 钩子并非孤例（[`yibaiba/harmonyos-skills-pack`](https://github.com/yibaiba/harmonyos-skills-pack) 也有 hooks 目录与 ArkTS 扫描器），本仓库的真实差异点是：

1. **OHPM 包名四级校验**（黑名单 → 白名单 → `ohpm view` CLI → 未知降级）—— [`tools/check-ohpm-deps.sh`](tools/check-ohpm-deps.sh)。同类无人做。
2. **AGC 提审 Top 20 拒因稳定 ID 体系**（`AGC-RJ-001..020`）+ 6 条高频项配可粘贴代码示例 —— `harmonyos-review` skill 与扫描器可用同一编号互引。同类无人做。
3. **awk 双状态机去注释预处理**（块注释 + 行注释）后再扫描，比直接 grep 假阳性更低 —— [`tools/hooks/lib/scan-arkts.sh`](tools/hooks/lib/scan-arkts.sh) 第 42-72 行
4. **OpenHarmony 官方文档镜像 bootstrap 脚本**（5300+ 中文 / 5100+ 英文 md 离线检索）—— 同类无人做
5. **测试 fixture 回归保障**（`tools/hooks/test-fixtures/` 故意写错的 .ets/.json5）—— 同类无人做

完整对比与同类生态全景见 [`docs/USAGE-GUIDE.md`](docs/USAGE-GUIDE.md) § B。

### 规则编号体系（精确说明）

本仓库的规则按用途分四层，**不应被合并表述为单一数字**：

| 层 | 数量 | 位置 | 用途 |
| --- | --- | --- | --- |
| **自动化扫描**（钩子触发） | 31 条（v0.3.0） | `tools/hooks/lib/scan-arkts.sh` 内联 + awk 装饰器上下文检测 | grep-based 快扫，毫秒级反馈；支持 [inline-suppress](.claude/skills/arkts-rules/SKILL.md#抑制-scanner-误报inline-suppress) |
| **代码审查清单** | 36 条（9 大类） | `.claude/skills/harmonyos-review/references/checklist.md` | review skill 引用的稳定 ID（`SEC-001` / `STATE-002` / `KIT-003` 等） |
| **AGC 提审拒因** | 20 条 | `07-publishing/checklist-2026-rejection-top20.md` | 上架审核拒因映射，含 `AGC-RJ-*` 稳定 ID |
| **OHPM 黑名单**（已知伪包） | ~25 项 | `tools/data/ohpm-blacklist.txt` + 脚本内联 | 防 AI 虚构包名 |

合计 ~94 条编号规则，分布在四个层；它们用于不同场景。

### Recipe Templates · 可粘贴的鸿蒙最小可用代码

[`samples/templates/`](samples/templates/) 下 4 个完整 recipe，每个都已通过 scan-arkts 全规则——拷贝到自家 `entry/src/main/ets/` 改 import 即用：

| Recipe | 含 | 何时用 |
| --- | --- | --- |
| [`permission/`](samples/templates/permission/) | 4 类敏感权限的运行时申请 + UI 解释 + 拒绝兜底（位置 / 相机 / 通知 / 麦克风） | 任何需要敏感权限的页面 |
| [`list/`](samples/templates/list/) | LazyForEach + IDataSource 标准实现 + 下拉刷新 + 上拉加载 | 长列表（消息/会话/Feed），数据源 ≥ 50 项或来自 RDB / 网络分页 |
| [`dark-mode/`](samples/templates/dark-mode/) | 系统主题跟随 + 资源限定符 + mediaquery 监听 | 上架要求支持深色模式（AGC-RJ-006） |
| [`login/`](samples/templates/login/) | 华为账号 SSO 接入指引（不写完整代码，给约束 + 文档链接 + 反模式提醒） | API 在 12 → 22 多次变化的模块；AI 训练数据是旧版，必须查官网 |

详细 README 在 [`samples/templates/README.md`](samples/templates/README.md)。

### Case Studies · 真实战疤

[`docs/case-studies/llm-chat-app.md`](docs/case-studies/llm-chat-app.md) — 真鸿蒙 LLM 对话客户端（LCC）M3-M12 多里程碑实战笔记。**症状 / 错误信息 / 修复 diff / 教训** 四段式，覆盖：Configuration import 命名空间陷阱、union content 拆双字段、SSE 流式 buffer 拼接、`useNormalizedOHMUrl` 主题切换、HUKS 加密资源句柄释放等 11 节。

---

## 快速开始

### 用法 A：把规则装进已有的鸿蒙 app（推荐，30 秒）

```bash
# 1) 进入你的鸿蒙 app 根目录（不是这个仓库）
cd ~/WorkSpace/apps/my-music-player

# 2) 一行装好（默认 Claude Code + Codex）—— 二选一

# 2a) curl（最直接）
curl -fsSL https://raw.githubusercontent.com/Octo-o-o-o/harmonyos-ai-workspace/main/tools/install.sh | bash

# 2b) npx（不必先 git clone；npm 包未发到 npm 时走 GitHub source 同样可用）
npx -y github:Octo-o-o-o/harmonyos-ai-workspace

# 加 Cursor / Copilot：
curl -fsSL https://raw.githubusercontent.com/Octo-o-o-o/harmonyos-ai-workspace/main/tools/install.sh | bash -s -- --targets=claude,codex,cursor,copilot
# 等价：npx -y github:Octo-o-o-o/harmonyos-ai-workspace --targets=claude,codex,cursor,copilot

# 国内 GitHub 不通时：
curl -fsSL https://raw.githubusercontent.com/Octo-o-o-o/harmonyos-ai-workspace/main/tools/install.sh | bash -s -- --mirror=ghproxy

# 卸载：
curl -fsSL https://raw.githubusercontent.com/Octo-o-o-o/harmonyos-ai-workspace/main/tools/install.sh | bash -s -- --uninstall
```

#### 5 分钟自测（验收装好了）

```bash
# 1. 模拟 Claude Code 写一个含反模式的 .ets 文件
mkdir -p test && cat > test/Bad.ets <<'EOF'
@Entry @Component struct X {
  @State items: number[] = [];
  build() { Button('+').onClick(() => { this.items.push(1) }) }
}
EOF

# 2. 触发钩子（模拟 Claude Code 的 PostToolUse 调用）
echo '{"tool_name":"Edit","tool_input":{"file_path":"test/Bad.ets"}}' | bash tools/hooks/post-edit.sh

# ✅ 预期输出：[STATE-002 · High] test/Bad.ets:3: this.items.push(1) ...
#    "数组就地 mutation 不触发重渲染。改写：this.X = [...this.X, item]"
# ✅ 同时写入 .claude/.harmonyos-last-scan.txt

# 3. 启动 Claude Code，开始写鸿蒙代码
claude
# 之后每次 Edit/Write .ets 钩子自动跑，违规反馈给 AI 自我修正

# 4. 清理测试文件
rm -rf test
```

### 用法 B：把整个工作区 clone 当参考库

```bash
# clone 到本地
git clone https://github.com/Octo-o-o-o/harmonyos-ai-workspace.git ~/WorkSpace/HarmonyOS_DevSpace
cd ~/WorkSpace/HarmonyOS_DevSpace

# 拉取 OpenHarmony 官方文档镜像（约 2.7 GB，不入主分支）
bash tools/bootstrap-upstream-docs.sh

# 校验本机环境（macOS Apple Silicon 默认）
bash tools/verify-environment.sh

# 没装 DevEco Studio 的话用脚本辅助
bash tools/install-deveco-prereqs.sh

# 安装 MCP-HarmonyOS（让 AI 直接查设备 / 项目状态）
npm install -g mcp-harmonyos
```

适合：想系统学习鸿蒙、想让 AI 助手在本目录开发、想贡献到本仓库。

---

## 常见故障排查

### 钩子没反应（Edit `.ets` 后没看到扫描输出）

```bash
# 1. 确认 settings.json 存在且配置正确
cat .claude/settings.json
# → 应含 "PostToolUse" 与 "tools/hooks/post-edit.sh"

# 2. 直接跑钩子测试（绕过 Claude Code）
echo '{"tool_name":"Edit","tool_input":{"file_path":"path/to/your.ets"}}' | bash tools/hooks/post-edit.sh

# 3. 开启调试日志
HOOK_DEBUG=1 bash tools/hooks/post-edit.sh < /dev/null

# 4. 检查脚本可执行
ls -la tools/hooks/post-edit.sh tools/hooks/lib/*.sh
chmod +x tools/hooks/post-edit.sh tools/hooks/lib/*.sh

# 5. 重启 Claude Code（settings.json 改动需重启）
```

### OHPM 校验报"无法离线核验"

```bash
# 这是预期：OHPM Registry 没公开稳定 API，脚本默认走"黑/白名单 + ohpm CLI"
# 让 ohpm CLI 在 PATH（DevEco 装好就有）：
ls ~/Library/Huawei/Sdk/*/openharmony/toolchains/ohpm*
export PATH="$PATH:~/Library/Huawei/Sdk/HarmonyOS-NEXT-DB1/openharmony/toolchains/ohpm/bin"

# 之后未知包会通过 ohpm CLI 实时查询
```

### `hvigorw codeLinter` 找不到

```bash
# DevEco 默认装在 ~/Library/Huawei/Sdk/，run-linter.sh 自动找；如失败：
which hvigorw
# 没有 → 在鸿蒙工程根目录运行（应有项目自带的 ./hvigorw）
cd ~/WorkSpace/apps/my-app && bash ../../HarmonyOS_DevSpace/tools/run-linter.sh
```

### upstream-docs 拉取很慢

```bash
# 用 Gitee 备源（自动兜底）：
bash tools/bootstrap-upstream-docs.sh
# 或 --force 重拉
```

### 想 fork 维护自己版本

把所有 `Octo-o-o-o/harmonyos-ai-workspace` 替换为你 fork 后的地址：

```bash
grep -rln 'Octo-o-o-o' --include='*.md' --include='*.sh' --include='*.json' . | xargs sed -i '' 's|Octo-o-o-o|YOUR_GITHUB_USER|g'
```

涉及文件：`README.md` / `CHANGELOG.md` / `tools/install.sh` 顶部 `REPO_OWNER`。

---

## 进阶用法

- **多 app 共享一套规则** / **AI 启动姿势** / **三层发布策略** / **与同类项目差异化对比** → 见 [`docs/USAGE-GUIDE.md`](docs/USAGE-GUIDE.md)
- **目录全图** → 见 [`CLAUDE.md` § 3 目录布局](CLAUDE.md)
- **快速判断"问题去哪查"** → 见 [`CLAUDE.md` § 2 快速判断](CLAUDE.md)

---

## 关键事实（2026-05）

- **当前消费稳定版**：HarmonyOS 6.0.2 / **API 22**（2026-01-23 起推送）
- **首发稳定版**：HarmonyOS 6.0.1 / **API 21**（2025-11-25）
- **HarmonyOS 6.1 开发者 Beta**：2026-02-07 对中国 5 万开发者开放
- **新项目建议**：targetSDK API 21，minSDK API 12
- **API 20 是 2025-09-25 仅开发者版**，不要选作 targetSDK
- **主语言**：ArkTS（增强 TypeScript）
- **UI 框架**：ArkUI（声明式，V1 + V2 不混用）
- **应用模型**：Stage 模型（FA 已废弃）
- **包格式**：`.hap`（单 module）/ `.app`（应用包）/ `.har`（静态库）/ `.hsp`（共享库）

---

## 给 AI 助手用的关键规则（精华版）

1. **不要凭训练数据写 API**：先查 `upstream-docs/.../reference/`，没有再上 [developer.huawei.com](https://developer.huawei.com/consumer/cn/)
2. **状态变更必须替换引用**（统计学第一坑）：`this.list.push(x)` 不会重渲染，要 `this.list = [...this.list, x]`
3. **ArkTS 严格子集**：禁 `any` / 解构 / 索引签名 / 对象字面量无类型 / for…in / `delete`
4. **import 用 `@kit.*`**，不要 `@ohos.*`（旧式）
5. **V1 / V2 状态装饰器不混用**：一个 `.ets` 文件二选一
6. **改完代码必跑**：`hvigorw codeLinter && hvigorw assembleHap -p buildMode=debug`
7. **不要引入 npm 包**：只能用 OHPM 发布的 `.har`/`.hsp`

完整版见 [`CLAUDE.md`](CLAUDE.md) 第 0、11、12、13 节。

---

## 文档更新

```bash
# 重新拉取 upstream-docs（覆盖现有镜像）
bash tools/bootstrap-upstream-docs.sh --force
```

---

## 贡献与反馈

- 贡献流程：[`CONTRIBUTING.md`](CONTRIBUTING.md)
- 版本历史：[`CHANGELOG.md`](CHANGELOG.md)
- 发现规则错误 / 补 API / 加 Skill：欢迎 PR
- 找了一圈也没解决你的鸿蒙问题：开 issue，附上 DevEco 版本、API Level、`hvigorw codeLinter` 输出

---

## 许可

- 本仓库自创内容（指南、`CLAUDE.md`、`AGENTS.md`、`.claude/skills/`、脚本、示例）：**MIT License**（详见 [`LICENSE`](LICENSE)）
- `upstream-docs/openharmony-docs/`（运行 bootstrap 脚本拉取）：CC-BY-4.0，版权归 **OpenAtom Foundation / OpenHarmony 项目**，使用须按 CC-BY-4.0 署名

---

## 相关

- OpenHarmony 官网：<https://www.openharmony.cn/>
- 华为开发者联盟：<https://developer.huawei.com/consumer/cn/>
- DevEco Studio 下载：<https://developer.huawei.com/consumer/cn/deveco-studio/>
- OHPM 包仓库：<https://ohpm.openharmony.cn/>
- Anthropic Claude Code 文档：<https://docs.claude.com/en/docs/claude-code>
- OpenAI Codex CLI：<https://github.com/openai/codex>
- AGENTS.md 跨工具规范：<https://agents.md/>
