# HarmonyOS DevSpace

> 让 **Claude Code / Codex CLI / Cursor / Copilot** 写出能编译过的鸿蒙代码。
>
> 基线：裸 LLM 在 ArkTS 上 Pass@1 仅 **3.13%**（[ArkEval](https://arxiv.org/html/2602.08866)）。本仓库通过**规则注入 + Edit 后自动校验 + OHPM 包名核验**把这个数字显著拉高。

## 5 秒决策：你应该走哪条路？

```
┌──────────────────────────────────────────────────────────────┐
│ 我已经有鸿蒙 app 项目，想让 AI 写代码不踩 ArkTS 坑           │
│   → 用法 A：一行 curl 把规则装进 app（不要 clone 这个仓库） │
└──────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────┐
│ 我想系统学鸿蒙开发 / 想读完整官方文档 / 想给本仓库贡献       │
│   → 用法 B：git clone 整个工作区到本地                       │
└──────────────────────────────────────────────────────────────┘
```

> **仓库地址**：<https://github.com/Octo-o-o-o/harmonyos-ai-workspace>  · 想 fork 维护自己版本时，记得把命令中的 `Octo-o-o-o` 替换为你的 GitHub 用户名。

---

## 内置内容

- **AI 助手规则集**：`CLAUDE.md`（含 ArkTS 硬约束、状态管理坑、构建/调试/上架检查清单）+ `AGENTS.md`（跨工具简版，Codex / Cursor / Aider 通用）
- **PostToolUse 钩子**：Claude Code 每次 Edit/Write 后自动跑 ArkTS 反模式扫描（`tools/hooks/lib/scan-arkts.sh`）+ OHPM 包名校验（`tools/check-ohpm-deps.sh`），违规反馈到 AI 上下文让其自我修正——**这是本仓库的核心差异化能力**
- **Claude Skills**：`.claude/skills/` 下 5 个按需触发的小卡片（arkts-rules / state-management / build-debug / signing-publish / harmonyos-review）+ `manifest.json` 元数据
- **多工具 fan-out**：`tools/generate-ai-configs.sh` 单源同步到 Cursor `.mdc` / Copilot instructions
- **CLI 工具集**：
  - `tools/install.sh` —— curl-pipeable 一行装到任意鸿蒙 app
  - `tools/run-linter.sh` —— 离线 codeLinter wrapper（不依赖 DevEco GUI）
  - `tools/check-ohpm-deps.sh` —— OHPM 包名校验
  - `tools/bootstrap-upstream-docs.sh` —— 拉取官方文档镜像
- **完整官方文档镜像**：5300+ 中文 + 5100+ 英文 markdown，来自 OpenHarmony 官方仓库（首次 clone 后跑 `bootstrap-upstream-docs.sh` 拉取，约 2.7 GB；不入主分支）
- **MCP 配置**：`.mcp.json` 已接通 [`mcp-harmonyos`](https://www.npmjs.com/package/mcp-harmonyos)
- **十大主题指南**（`00-` 至 `09-`）：环境搭建、ArkTS、ArkUI、Platform APIs、构建调试、最佳实践、设计、上架、资源链接、Quick Reference
- **2026 提审拒因清单**：[`07-publishing/checklist-2026-rejection-top20.md`](07-publishing/checklist-2026-rejection-top20.md) Top 20 拒因 + 修复 + 自查命令
- **测试 fixture**：`tools/hooks/test-fixtures/` 故意写错的 .ets 用于校验脚本回归

---

## 快速开始

### 用法 A：把规则装进已有的鸿蒙 app（推荐，30 秒）

```bash
# 1) 进入你的鸿蒙 app 根目录（不是这个仓库）
cd ~/WorkSpace/apps/my-music-player

# 2) 一行装好（默认 Claude Code + Codex）
curl -fsSL https://raw.githubusercontent.com/Octo-o-o-o/harmonyos-ai-workspace/main/tools/install.sh | bash

# 加 Cursor / Copilot：
curl -fsSL ... | bash -s -- --targets=claude,codex,cursor,copilot

# 国内 GitHub 不通时：
curl -fsSL ... | bash -s -- --mirror=ghproxy

# 卸载：
curl -fsSL ... | bash -s -- --uninstall
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

## 推荐使用方式

### A. 个人自用（开发自己的鸿蒙 app）

**目录约定**——`HarmonyOS_DevSpace` 是参考库，**不要**把真业务 app 放进 `samples/`：

```
~/WorkSpace/
├── HarmonyOS_DevSpace/         ← 本仓库（参考库 + AI 规则）
└── apps/
    ├── my-music-player/         ← 真 app A，DevEco Studio 项目
    ├── my-todo/                 ← 真 app B
    └── ...
```

**让 AI 助手在 app 项目里也能读到本仓库**——三种方式任选：

```bash
# 方式 1：每个 app 软链 CLAUDE.md / AGENTS.md（最直接）
cd ~/WorkSpace/apps/my-music-player
ln -s ../../HarmonyOS_DevSpace/CLAUDE.md CLAUDE.md
ln -s ../../HarmonyOS_DevSpace/AGENTS.md AGENTS.md
ln -s ../../HarmonyOS_DevSpace/.mcp.json .mcp.json

# 方式 2：在 ~/.claude/CLAUDE.md（user-level memory）写一行（推荐）
# "鸿蒙开发统一参考 ~/WorkSpace/HarmonyOS_DevSpace/，遇到 ArkTS / ArkUI / 鸿蒙 API
# 问题先读该目录下的 CLAUDE.md 与 upstream-docs/。"
# → 任何目录启动 Claude Code 都自带此上下文

# 方式 3：项目级 CLAUDE.md 顶部 import（柔性）
# 在 my-music-player/CLAUDE.md 里写：
# > 通用鸿蒙开发规则继承自 ../../HarmonyOS_DevSpace/CLAUDE.md
```

**启动 Claude Code 的两种姿势**：

```bash
# 学习 / 改文档
cd ~/WorkSpace/HarmonyOS_DevSpace && claude

# 实际开发功能
cd ~/WorkSpace/apps/my-music-player && claude
# Claude 自动读本目录的 CLAUDE.md，并能用 Bash 工具读 ../../HarmonyOS_DevSpace/...
```

**Codex CLI 同理**——在 app 根放 `AGENTS.md`（软链或独立写）即可。Codex 默认会从 git root 向上查找 `AGENTS.md`，并支持 `~/.codex/AGENTS.md` 全局兜底。

### B. 开源给其他开发者（推荐分三层）

```
┌──────────────────────────────────────────────────────────────┐
│ Layer 1 · harmonyos-ai-workspace  ← 本仓库                   │
│ 形态：参考工作区（规则 + Skills + 文档镜像 + 脚手架）        │
│ 受众：希望用 Claude/Codex/Cursor 开发鸿蒙的工程师             │
│ 安装：git clone + bootstrap-upstream-docs.sh                 │
└──────────────────────────────────────────────────────────────┘
              ↓ 抽规则                       ↓ 抽骨架
┌────────────────────────────┐   ┌────────────────────────────┐
│ Layer 2 ·                  │   │ Layer 3 ·                  │
│ claude-code-harmonyos-     │   │ harmonyos-app-template     │
│   skills (Skill 包)        │   │   (项目模板)               │
│ 形态：可重用 Claude Plugin │   │ 形态：DevEco 可直接打开    │
│ 安装：/plugin install      │   │ 安装：degit your/template  │
│   github:你/...            │   │   my-app                   │
└────────────────────────────┘   └────────────────────────────┘
```

**当前版本（v1.0）已完成 Layer 1**。Layer 2 的 Skill 文件已在 `.claude/skills/`，未来抽出独立仓库即可。Layer 3 等跑通 1 个真 app 后再做。详细路线图见 [`OPEN-SOURCE-STRATEGY.md`](OPEN-SOURCE-STRATEGY.md)。

### C. 与已有同类项目的差异化

截至 2026-05，GitHub 上有几个相邻项目：

| 项目 | 形态 | 与本仓库的差异 |
| --- | --- | --- |
| `DengShiyingA/harmonyos-ai-skill` | 单源文件 → 11+ AI 工具配置生成器 | 他们偏"配置导出器"；本仓库是**结构化工作区**（含分类目录 + 上游文档镜像 + Skills + 脚手架） |
| `yibaiba/harmonyos-skills-pack` | Skills 包，有 manifest | 他们偏"上架 / 模块模板"；本仓库覆盖**语言迁移 + 状态管理 V1/V2 + 构建/调试/签名**全链路 |
| `CoreyLyn/harmonyos-skills` | 较小的 Agent Skills | 体量与覆盖面都小一档 |
| `aresbit/arkts-dev-skill` | 单 SKILL.md | 仅 ArkTS 语法层 |

如果你要做的是"可重用的 AI Skill 包"，已有项目可参考；本仓库的差异点在于**完整工作区 + 官方文档镜像 + 三层发布策略**——它先是给 AI 看的"百科全书"，再衍生出 Skill / 模板。

---

## 目录结构

```
HarmonyOS_DevSpace/
├── CLAUDE.md / AGENTS.md         AI 助手主入口（同源不同形）
├── README.md                     本文件
├── OPEN-SOURCE-STRATEGY.md       自用 + 开源分发策略
├── CONTRIBUTING.md               贡献指南
├── CHANGELOG.md                  版本变更
├── LICENSE                       MIT
├── .mcp.json                     MCP-HarmonyOS 服务配置
├── .gitignore                    含鸿蒙生态产物
├── .claude/skills/               按需触发的 4 个 Skills
├── .github/workflows/            CI（markdown lint）
├── 00-getting-started/           环境搭建、第一个项目、签名、AI 协作
├── 01-language-arkts/            ArkTS 语言：装饰器、TS 差异、状态速查
├── 02-framework-arkui/           ArkUI 声明式 UI、布局、动画
├── 03-platform-apis/             Kit 系统能力分类索引
├── 04-build-debug-tools/         Hvigor / OHPM / hdc / Inspector / Profiler
├── 05-best-practices/            性能 / 多端 / 安全 / 包大小 / i18n / a11y
├── 06-design-guidelines/         鸿蒙设计语言、控件规范
├── 07-publishing/                AppGallery 上架、签名证书、灰度
├── 08-resources-links/           精选官方/社区链接
├── 09-quick-reference/           cheat sheet（装饰器、命令、错误码）
├── samples/                      示例项目（路线图见目录 README）
├── tools/                        安装与校验脚本
└── upstream-docs/openharmony-docs/   OpenHarmony 官方文档（bootstrap 后存在；不入主分支）
```

详细索引见 [`CLAUDE.md`](CLAUDE.md) 第 2 节"快速判断"表。

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
