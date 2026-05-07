# HarmonyOS AI Workspace

[![npm version](https://img.shields.io/npm/v/harmonyos-ai-workspace.svg)](https://www.npmjs.com/package/harmonyos-ai-workspace)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/Octo-o-o-o/harmonyos-ai-workspace)](https://github.com/Octo-o-o-o/harmonyos-ai-workspace/releases/latest)

> **一行命令把"鸿蒙领域规则包"装进你的 app，让 Claude / Codex / Cursor / Copilot 写出能编译过的鸿蒙代码。**

```bash
cd ~/WorkSpace/apps/my-harmony-app    # 进你的鸿蒙 app 根目录
npx -y harmonyos-ai-workspace          # 30 秒搞定，0 改你的源码
```

---

## 这个项目对谁有帮助？

| 你是 | 你会得到 |
| --- | --- |
| 🆕 **vibe coder（不熟鸿蒙，让 AI 写）** | AI 不再写 ArkTS 编译错；不再瞎编 OHPM 包名；不再让 UI 不刷新；编译失败时 AI 能精确定位 |
| 🛠 **老 HarmonyOS 开发者（让 AI 协助）** | 一套大家都遵守的硬约束（V1/V2 选型、状态铁律、装饰器规范）；编辑 `.ets` 后自动校验；提审 Top 20 拒因预防式提示 |
| 👥 **团队 lead（多人多 AI 工具）** | 同一份规则同时喂 Claude Code / Codex / Cursor / Copilot；钩子保证违规 0 漏过；新人 git clone 即拥有完整规则 |

**前置要求**：你在用 Claude Code / Codex CLI / Cursor / GitHub Copilot 中至少一个；本仓库不是独立 IDE，是给它们装的"鸿蒙领域规则包"。

没装过 AI 助手 / DevEco Studio？看 [`docs/SETUP-FROM-SCRATCH.md`](docs/SETUP-FROM-SCRATCH.md)（macOS 干净状态到 hello world，30-60 分钟）。

---

## 装了能解决什么问题？

| 痛点 | 没装本仓库 | 装了之后 |
| --- | --- | --- |
| AI 写 ArkTS Pass@1 仅 **3.13%**（[ArkEval 论文](https://arxiv.org/html/2602.08866) 实测） | AI 写 100 行代码 ~97 行编译不过 | 规则注入 + 钩子校验，假阳率实测 **21% → 0%** |
| AI 瞎编 OHPM 包（如 `@ohos/lottie-player`、`@ohos/axios`） | `ohpm install` 失败浪费 10 分钟 | 安装时三层校验：黑名单 → 白名单 → `ohpm view`，假包当场拦截 |
| AI 写 `this.list.push(x)` 状态不刷新（**LLM 第一坑**） | UI 不更新，调试半小时才发现 | 钩子立刻报 `STATE-002 · High`，给改写示例 |
| AI 引用旧 API（DevEco 12 → 22 多次变化） | 用了已弃用的 `picker.PhotoViewPicker` | `ARKTS-DEPRECATED-PICKER` 即时拦截 + 给新 API |
| AGC 上架前才发现拒因 | 提审被打回再修 = 1 周 | 20 条 `AGC-RJ-*` 稳定 ID 编辑时就提示 |
| 多 AI 工具规则不一致（Claude / Cursor 各写一套） | 同一项目下 AI 给不同建议 | 单源 fan-out：8 个 SKILL → Cursor `.mdc` + Copilot instructions |

---

## 30 秒装好（推荐）

```bash
# 1) 进你的鸿蒙 app 根目录
cd ~/WorkSpace/apps/my-harmony-app

# 2) 一行装好
npx -y harmonyos-ai-workspace

# 3) 启动你的 AI 助手——CLAUDE.md / AGENTS.md 自动加载
claude    # 或 codex / cursor
```

**v0.4 起的安全保障**：
- ✅ 已存在的 `CLAUDE.md` / `AGENTS.md` 会被**保护**（绝不覆盖）
- ✅ 安装报告明示哪些 `written` / 哪些 `skipped`
- ✅ 卸载只删本工具写入的（`.harmonyos-ai-workspace.manifest` + sha256 校验）

更多选项：

```bash
npx -y harmonyos-ai-workspace --dry-run                              # 预览不真写
npx -y harmonyos-ai-workspace --targets=claude,codex,cursor,copilot  # 加 Cursor / Copilot
npx -y harmonyos-ai-workspace --mirror=ghproxy                       # 国内 GitHub 不通时
npx -y harmonyos-ai-workspace --force                                # 覆盖已存在文件
npx -y harmonyos-ai-workspace --uninstall                            # 安全卸载
```

---

## 5 分钟试一下（验收装好了）

```bash
# 1) 模拟 AI 写一个反模式（数组就地 mutation = LLM 写鸿蒙的第一大坑）
mkdir -p test && cat > test/Bad.ets <<'EOF'
@Entry @Component struct X {
  @State items: number[] = [];
  build() { Button('+').onClick(() => { this.items.push(1) }) }
}
EOF

# 2) 触发钩子（模拟 Claude Code 编辑文件后调用）
echo '{"tool_name":"Edit","tool_input":{"file_path":"test/Bad.ets"}}' | bash tools/hooks/post-edit.sh

# ✅ 预期看到：
#   [STATE-002 · High] test/Bad.ets:3: this.items.push(1) ...
#   ↳ 数组就地 mutation 不触发重渲染。改写：this.X = [...this.X, item]

# 3) 清理
rm -rf test
```

**看到 `STATE-002 · High` = 钩子工作**。从此每次 Claude Code 编辑 `.ets` / `.ts` 自动跑这套校验，违规会反馈给 AI 让它自我修正。

---

## 📖 完整使用说明书

**装好之后怎么开始干活？** → [`docs/USER-GUIDE.md`](docs/USER-GUIDE.md)

里面写了：
- 首次使用：5 分钟验收 + 第一次让 AI 改个页面
- 日常工作流：跟 Claude Code / Codex / Cursor / Copilot 一起写代码
- 典型任务：写新页面、加权限、接 LLM API、做下拉刷新、深色模式、编译失败处理
- AI 协作"魔法咒语"：怎么让 AI 充分用规则（引稳定 ID、读 case study、跑 scanner）
- 卸载与升级

---

## 它怎么工作（原理）

```
┌──────────────────────────────────────────────────────────────────┐
│   你的鸿蒙 app 项目                                              │
│   ┌─────────┐                                                    │
│   │ AI 助手 │  Claude Code / Codex / Cursor / Copilot           │
│   └────┬────┘                                                    │
│        │ 启动时自动加载                                          │
│        ▼                                                          │
│   CLAUDE.md / AGENTS.md / .cursor/rules/ / .github/copilot-…     │
│        │ AI 读到鸿蒙硬约束 + 8 SKILL 触发索引                    │
│        ▼                                                          │
│   AI 写代码 → Edit .ets / .ts / oh-package.json5                 │
│        │                                                          │
│        ▼ ⚡ 钩子触发（仅 Claude Code 强校验）                    │
│   ┌─────────────────────────────────────────────────────┐        │
│   │ tools/hooks/post-edit.sh                            │        │
│   │  ├─ scan-arkts.sh   31 条规则 + 装饰器上下文 + 折叠   │        │
│   │  ├─ check-ohpm-deps.sh  4 类（FAKE/NET/UNKNOWN/OK） │        │
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

详细工作流见 [`docs/USER-GUIDE.md` § 3](docs/USER-GUIDE.md)。

---

## 内置内容

| 资产 | 内容 |
| --- | --- |
| **AI 规则集** | `CLAUDE.md`（Claude Code）+ `AGENTS.md`（[agents.md 标准](https://agents.md/) 24+ 工具通用）+ 8 个按需触发的 [`.claude/skills/`](.claude/skills/) |
| **8 个 SKILL** | `arkts-rules` / `state-management` / `build-debug` / `signing-publish` / `harmonyos-review` / `runtime-pitfalls` / `multimodal-llm` / `web-bridge` |
| **PostToolUse 钩子链路** | Edit `.ets`/`.ts`/`oh-package.json5` 后自动跑 ArkTS 反模式扫描 + OHPM 包名核验 + 权限提示 |
| **多工具 fan-out** | 单源 `.claude/skills/*/SKILL.md` → Cursor `.mdc` + Copilot instructions |
| **CLI 工具集** | `install.sh`（manifest + sha256 安装）/ `run-linter.sh`（离线 codeLinter）/ `check-ohpm-deps.sh`（4 类校验）/ `check-rename-module.sh`（模块改名一致性）/ `test-suite.sh`（19 项回归断言） |
| **Recipe Templates** | 4 个可粘贴最小可用代码（`permission/` / `list/` / `dark-mode/` / `login/`） |
| **2026 提审 Top 20 拒因** | [`07-publishing/checklist-2026-rejection-top20.md`](07-publishing/checklist-2026-rejection-top20.md)，含 `AGC-RJ-001..020` 稳定 ID + 6 条高频项配可粘贴代码 |
| **Case Studies** | [`docs/case-studies/llm-chat-app.md`](docs/case-studies/llm-chat-app.md) — 真鸿蒙 LLM 对话 app M3-M12 实战，11 节"症状/错误信息/修复 diff/教训"四段式 |
| **测试 fixture** | 9 个回归 fixture 覆盖 inline 装饰器 / `@CustomDialog` / `@Reusable` / 普通工具类等边界 |
| **MCP** | `.mcp.json` 接通 `mcp-harmonyos`（npx 自动）；动作型 MCP 接入指引见 [`docs/MCP-INTEGRATION.md`](docs/MCP-INTEGRATION.md) |
| **可选官方文档镜像** | 5300+ 中文 + 5100+ 英文 OpenHarmony md（按需 `bootstrap-upstream-docs.sh -y` 拉，~2.7 GB） |

### 真正独有的能力（vs 同类项目）

PostToolUse 钩子并非孤例（[`yibaiba/harmonyos-skills-pack`](https://github.com/yibaiba/harmonyos-skills-pack) 也有 hooks），本仓库的真实差异点：

1. **OHPM 包名四类校验**（FAKE / NET / UNKNOWN / OK）+ 15s timeout —— [`tools/check-ohpm-deps.sh`](tools/check-ohpm-deps.sh)。同类无人做
2. **AGC 提审 Top 20 拒因稳定 ID 体系**（`AGC-RJ-001..020`）+ 高频项配可粘贴代码 —— `harmonyos-review` skill 与扫描器可用同一编号互引
3. **awk 装饰器上下文检测** + **inline-suppress** + **真 collapse 折叠** —— `tools/hooks/lib/scan-arkts.sh`，PrivateTalk 真工程实测假阳率 0%
4. **install/uninstall manifest + sha256** —— v0.4.0 起，用户原 `CLAUDE.md` 永不被吞，本工具写的所有文件可精确卸载
5. **OpenHarmony 官方文档镜像 bootstrap**（5300+ 中文 / 5100+ 英文 md 离线检索）+ **真鸿蒙 LLM Chat case study**（实战四段式）

完整对比见 [`docs/USAGE-GUIDE.md`](docs/USAGE-GUIDE.md) § B。

### 规则编号体系（精确说明）

本仓库的规则按用途分四层，**不应被合并表述为单一数字**：

| 层 | 数量 | 位置 | 用途 |
| --- | --- | --- | --- |
| **自动化扫描**（钩子触发） | 31 条 | `tools/hooks/lib/scan-arkts.sh` 内联 + awk 装饰器上下文检测 | grep-based 快扫，毫秒级反馈；支持 [inline-suppress](.claude/skills/arkts-rules/SKILL.md#抑制-scanner-误报inline-suppress) |
| **代码审查清单** | 36 条（9 大类） | `.claude/skills/harmonyos-review/references/checklist.md` | review skill 引用的稳定 ID（`SEC-001` / `STATE-002` / `KIT-003` 等） |
| **AGC 提审拒因** | 20 条 | `07-publishing/checklist-2026-rejection-top20.md` | 上架审核拒因映射，含 `AGC-RJ-*` 稳定 ID |
| **OHPM 黑名单**（已知伪包） | ~25 项 | `tools/data/ohpm-blacklist.txt` + 脚本内联 | 防 AI 虚构包名 |

合计 ~94 条编号规则，分布在四层；它们用于不同场景。

---

## 版本契约（Version Contract）

```yaml
# 鸿蒙系统侧（API 编号是单一权威，不同 API 对应不同 HarmonyOS 系统版本）
harmonyos_system:
  min_supported_api:        12   # API 12 = HarmonyOS 5（NEXT）时代起，本仓库规则适用最低线
  current_consumer_stable:  22   # API 22 = HarmonyOS 6.0.2，2026-01-23 起对 Mate 80/70/Pura 80 推送
  first_stable_release:     21   # API 21 = HarmonyOS 6.0.1，2025-11-25 随 Mate 80 首发
  developer_preview_api:    23   # API 23 Developer Beta（最新预览，跟随华为发布节奏 — 跑生产 app 别选）
  recommended_target:       21   # 新项目推荐 targetSDK
  recommended_min:          12   # 新项目推荐 minSDK

toolchain:
  arkts:          ">= 1.2.0"
  deveco_studio:  ">= 6.0"
  ohpm:           ">= 1.4"

ai_assistants:
  claude_code:    ">= 0.5"
  codex_cli:      ">= 0.1"
  cursor:         ">= 1.0"
  copilot:        "ChatGPT-class instructions OK"

last_verified_docs_snapshot: "2026-05-07"
```

> **如何读这张表**：API 编号才是单一权威——HarmonyOS 5 = API 12+ 时代，HarmonyOS 6 = API 21+ 时代。"6.0" / "6.0.2" / "6.1" 这种系统版本号会在不同发布节点指向不同 API 编号，直接看 API 数字最准。
>
> **生产应用选 API 22**（minSDK 12 / target 21–22 都行）；developer beta（API 23）当下仅尝鲜用。鸿蒙生态快速迭代：本仓库每次发版前在 `last_verified_docs_snapshot` 日期对齐一次"当前消费稳定版"。

---

## 替代安装方式

### 用法 A2：curl one-liner（不依赖 npm）

```bash
curl -fsSL https://raw.githubusercontent.com/Octo-o-o-o/harmonyos-ai-workspace/main/tools/install.sh | bash
```

### 用法 B：clone 整个工作区（学习 / 贡献用）

```bash
git clone https://github.com/Octo-o-o-o/harmonyos-ai-workspace.git ~/WorkSpace/HarmonyOS_DevSpace
cd ~/WorkSpace/HarmonyOS_DevSpace
bash tools/bootstrap-upstream-docs.sh   # 拉 OpenHarmony 官方文档镜像（~2.7 GB，可选）
bash tools/verify-environment.sh        # 检查本机环境
```

适合：想系统学习鸿蒙、想让 AI 在本目录开发、想给本仓库贡献。

### 用法 C：从零开始（macOS 干净状态）

```bash
git clone https://github.com/Octo-o-o-o/harmonyos-ai-workspace.git ~/WorkSpace/HarmonyOS_DevSpace
cd ~/WorkSpace/HarmonyOS_DevSpace
bash tools/setup-from-scratch.sh        # 半自动向导：装基础工具 → 引导装 DevEco → 配 PATH → 装 Claude Code
```

完整指南见 [`docs/SETUP-FROM-SCRATCH.md`](docs/SETUP-FROM-SCRATCH.md)。

---

## 常见故障排查

### 编译/构建失败时，怎么把信号传给 AI 让它修

vibe coding 卡死的 90% 场景是"AI 写完看起来 OK 但 hvigorw 报错；我把错误贴给 AI，它瞎猜"。最高效路径：

```bash
# 1) 直接复制 hvigorw 的报错原文，含错误码
hvigorw assembleHap -p buildMode=debug 2>&1 | tail -30 | pbcopy   # macOS 进剪贴板

# 2) 把这段贴给 Claude/Codex/Cursor，附一句：
#    "请按 .claude/skills/arkts-rules/references/spec-quick-ref.md 里的稳定 ID
#     找出违反的规则编号 + 给最小 diff，不要重写整个文件"

# 3) 装包失败贴 hilog（hdc 真机）
hdc hilog | grep -E "FAULT|ERROR|9568" | tail -30

# 4) 钩子已经写过的违规会落到这里——下一轮启动 AI 前先让它读
cat .claude/.harmonyos-last-scan.txt 2>/dev/null
```

### 钩子没反应（Edit `.ets` 后没看到扫描输出）

```bash
cat .claude/settings.json                                          # 应含 PostToolUse + post-edit.sh 路径
echo '{"tool_name":"Edit","tool_input":{"file_path":"x.ets"}}' | \
  bash tools/hooks/post-edit.sh                                    # 直接跑钩子测试
HOOK_DEBUG=1 bash tools/hooks/post-edit.sh < /dev/null             # 开调试日志
chmod +x tools/hooks/post-edit.sh tools/hooks/lib/*.sh             # 修可执行位
# settings.json 改动需重启 Claude Code 才生效
```

### OHPM 校验报"无法离线核验"

```bash
# 让 ohpm CLI 在 PATH（DevEco 装好就有）
ls ~/Library/Huawei/Sdk/*/openharmony/toolchains/ohpm*
export PATH="$PATH:~/Library/Huawei/Sdk/HarmonyOS-NEXT-DB1/openharmony/toolchains/ohpm/bin"
```

### `hvigorw codeLinter` 找不到

```bash
which hvigorw   # 应有；没有就到鸿蒙工程根目录跑
cd ~/WorkSpace/apps/my-app && bash ../../HarmonyOS_DevSpace/tools/run-linter.sh
```

### 想 fork 维护自己版本

```bash
grep -rln 'Octo-o-o-o' --include='*.md' --include='*.sh' --include='*.json' . | \
  xargs sed -i '' 's|Octo-o-o-o|YOUR_GITHUB_USER|g'
```

涉及文件：`README.md` / `CHANGELOG.md` / `tools/install.sh` 顶部 `REPO_OWNER`。

更多故障场景见 [`docs/USER-GUIDE.md` § 6](docs/USER-GUIDE.md)。

---

## 给 AI 助手用的关键规则（精华版）

1. **不要凭训练数据写 API**：先查 `upstream-docs/.../reference/`，没有再上 [developer.huawei.com](https://developer.huawei.com/consumer/cn/)
2. **状态变更必须替换引用**（统计学第一坑）：`this.list.push(x)` 不会重渲染，要 `this.list = [...this.list, x]`
3. **ArkTS 严格子集**：禁 `any` / 解构 / 索引签名 / 对象字面量无类型 / for…in / `delete`
4. **import 用 `@kit.*`**，不要 `@ohos.*`（旧式）
5. **V1 / V2 状态装饰器不混用**：一个 `.ets` 文件二选一；**默认 V1**（生态最成熟）
6. **改完代码必跑**：`hvigorw codeLinter && hvigorw assembleHap -p buildMode=debug`
7. **不要引入 npm 包**：只能用 OHPM 发布的 `.har`/`.hsp`

完整版见 [`CLAUDE.md`](CLAUDE.md) 第 0、11、12、13 节 + 8 个 SKILL（按需触发）。

---

## 进阶 / 文档

- 📖 [使用说明书 USER-GUIDE.md](docs/USER-GUIDE.md) — 首次使用、日常工作流、典型任务、AI 协作魔法咒语
- 🛠 [进阶用法 USAGE-GUIDE.md](docs/USAGE-GUIDE.md) — 多 app 共享规则、三层发布策略、AI 启动姿势、与同类项目对比
- 🚀 [SETUP-FROM-SCRATCH.md](docs/SETUP-FROM-SCRATCH.md) — macOS 干净状态到第一行 `.ets` 跑通
- 🔌 [MCP-INTEGRATION.md](docs/MCP-INTEGRATION.md) — 接入第二个 MCP（动作型，hdc 控设备）
- 📋 [CLAUDE.md](CLAUDE.md) — Claude Code 项目级大宪章 + 8 SKILL 触发索引 + 目录全图
- 🤖 [AGENTS.md](AGENTS.md) — 跨工具通用宪法（24+ 工具兼容）
- 📜 [CHANGELOG.md](CHANGELOG.md) — 完整版本历史

---

## 关键事实（2026-05）

- **当前消费稳定版**：HarmonyOS 6.0.2 / **API 22**（2026-01-23 起推送）
- **首发稳定版**：HarmonyOS 6.0.1 / **API 21**（2025-11-25）
- **开发者 Beta**：API 23，跟随华为发布节奏
- **新项目建议**：targetSDK API 21，minSDK API 12
- **API 20 是 2025-09-25 仅开发者版**，不要选作 targetSDK
- **主语言**：ArkTS（增强 TypeScript） / **UI**：ArkUI（声明式，V1 默认）/ **应用模型**：Stage（FA 已废弃）
- **包格式**：`.hap`（单 module）/ `.app`（应用包）/ `.har`（静态库）/ `.hsp`（共享库）

---

## 贡献与反馈

- 贡献流程：[`CONTRIBUTING.md`](CONTRIBUTING.md)
- 版本历史：[`CHANGELOG.md`](CHANGELOG.md)
- 评审归档：[`docs/archive/reviews/`](docs/archive/reviews/) — 6 轮多视角评审 + PrivateTalk 真用户验收
- 发现规则错误 / 补 API / 加 Skill：欢迎 PR
- 找了一圈也没解决你的鸿蒙问题：开 issue，附 DevEco 版本、API Level、`hvigorw codeLinter` 输出

---

## 许可

- 本仓库自创内容（指南、`CLAUDE.md`、`AGENTS.md`、`.claude/skills/`、脚本、示例）：**MIT License**（详见 [`LICENSE`](LICENSE)）
- `upstream-docs/openharmony-docs/`（运行 bootstrap 拉取）：CC-BY-4.0，版权归 **OpenAtom Foundation / OpenHarmony 项目**

---

## 相关链接

- OpenHarmony 官网：<https://www.openharmony.cn/>
- 华为开发者联盟：<https://developer.huawei.com/consumer/cn/>
- DevEco Studio 下载：<https://developer.huawei.com/consumer/cn/deveco-studio/>
- OHPM 包仓库：<https://ohpm.openharmony.cn/>
- Anthropic Claude Code 文档：<https://docs.claude.com/en/docs/claude-code>
- OpenAI Codex CLI：<https://github.com/openai/codex>
- AGENTS.md 跨工具规范：<https://agents.md/>
