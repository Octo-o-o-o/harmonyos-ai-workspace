# HarmonyOS AI Workspace

[![npm version](https://img.shields.io/npm/v/harmonyos-ai-workspace.svg)](https://www.npmjs.com/package/harmonyos-ai-workspace)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/Octo-o-o-o/harmonyos-ai-workspace)](https://github.com/Octo-o-o-o/harmonyos-ai-workspace/releases/latest)

> **把鸿蒙 AI 协作装进你的 app：规则、Skills、钩子、脚手架和调试闭环一起交给 Claude / Codex / Cursor / Copilot，让 AI 写出的 ArkTS 更接近"能编译、能运行、能上架"。**

```bash
cd ~/WorkSpace/apps/my-harmony-app    # 进你的鸿蒙 app 根目录
npx -y harmonyos-ai-workspace          # 30 秒搞定，0 改你的源码
```

---

## 这个项目是什么？

**HarmonyOS AI Workspace 是一个面向鸿蒙应用开发的 AI 编码工作区安装器。**

它不是新的 IDE，也不是业务模板，更不是运行时依赖。它做的是把鸿蒙开发里 AI 最容易踩错的知识、规则和校验工具，安装到你的真实 HarmonyOS app 项目里：

| 它提供 | 用来解决 |
| --- | --- |
| `AGENTS.md` / `CLAUDE.md` / Skills / Cursor / Copilot 规则 | 让不同 AI 助手在同一套鸿蒙约束下工作 |
| ArkTS / ArkUI / OHPM / AGC 上架规则 | 降低 `any`、状态不刷新、伪包名、旧 API、拒审项等高频错误 |
| Edit 后钩子和扫描脚本 | 在 AI 写完 `.ets` / `.ts` / `oh-package.json5` 后立刻把违规反馈给 AI |
| `harmony-dev-cycle.sh` 调试闭环 | 让 AI agent 能跑 `build → install → run → hilog`，少依赖 DevEco GUI 手工切换 |
| 模板、case study、官方文档镜像入口 | 给 AI 和开发者一套可引用的鸿蒙工程经验库 |

项目目标很直接：**让 AI 成为可控的鸿蒙开发搭档，而不是只会生成"看起来像 TypeScript、实际过不了 ArkTS 编译"的代码补全器。**

---

## 目标客户

| 你是 | 你会得到 |
| --- | --- |
| 🆕 **vibe coder / 新手开发者** | 你不需要先背完 ArkTS 限制；AI 会被项目规则约束，写错时也会被扫描器及时拦住 |
| 🛠 **HarmonyOS 应用工程师** | 你可以把重复的语言规则、状态管理铁律、Kit API 习惯、构建排错流程交给 AI 和钩子处理 |
| 👥 **团队 lead / 架构负责人** | 你可以把一套鸿蒙工程规范同时分发给 Claude Code、Codex、Cursor、Copilot，并接入 pre-commit / CI |
| 🧩 **工具链 / 平台团队** | 你可以把它作为组织内 HarmonyOS AI 开发基线，再按业务模块扩展自家规则、模板和审查清单 |

**前置要求**：你在用 Claude Code / Codex CLI / Cursor / GitHub Copilot 中至少一个；本仓库不是独立 IDE，是给它们装的"鸿蒙领域规则包"。

没装过 AI 助手 / DevEco Studio？看 [`docs/SETUP-FROM-SCRATCH.md`](docs/SETUP-FROM-SCRATCH.md)（macOS 干净状态到 hello world，30-60 分钟）。

---

## 它应该怎么用？

最常见的使用方式是：**不要在本仓库里写你的业务 app；把规则安装进你自己的鸿蒙 app 根目录。**

```
~/WorkSpace/
├── HarmonyOS_DevSpace/              # 本仓库：规则、脚本、模板、文档、case study
└── apps/
    └── my-harmony-app/              # 你的真实 DevEco / HarmonyOS app
        ├── entry/
        ├── oh-package.json5
        ├── AGENTS.md                # npx 安装后写入
        ├── .agents/skills/          # Codex 使用
        ├── CLAUDE.md                # Claude Code 使用
        ├── .claude/skills/          # Claude Code 使用
        └── tools/                   # 扫描、构建、调试脚本
```

日常工作流：

1. 在真实 app 根目录运行 `npx -y harmonyos-ai-workspace`。
2. 从同一个 app 根目录启动 `claude` / `codex`，或用 Cursor / Copilot 打开这个项目。
3. 直接让 AI 改 `.ets` / `.ts` / `module.json5` / `oh-package.json5`，不需要每次重复粘贴鸿蒙规则。
4. AI 编辑后，Claude Code 会触发 PostToolUse 钩子；其他工具可手动或通过 pre-commit 跑 `tools/hooks/lib/scan-arkts.sh`。
5. 功能完成后跑 `bash tools/harmony-dev-cycle.sh quick-check`，需要真编译时跑 `build-check` 或 `cycle-once`。
6. 团队场景把扫描脚本接到 pre-commit / CI，让所有 AI 工具和所有人共享同一套底线。

如果你只是想学习、贡献或维护这套规则，再 `git clone` 本仓库；如果你的 HarmonyOS shell 在大 monorepo 子目录里，用 [`samples/integrations/monorepo-consumer/`](samples/integrations/monorepo-consumer/) 的 wrapper 模式。

---

## 装了能解决什么问题？

| 痛点 | 没装本仓库 | 装了之后 |
| --- | --- | --- |
| AI 写 ArkTS Pass@1 仅 **3.13%**（[ArkEval 论文](https://arxiv.org/html/2602.08866) 实测） | AI 写 100 行代码 ~97 行编译不过 | 规则注入 + 钩子校验，假阳率实测 **21% → 0%** |
| AI 瞎编 OHPM 包（如 `@ohos/lottie-player`、`@ohos/dayjs`） | `ohpm install` 失败浪费 10 分钟 | 安装时多层校验：黑名单 → 白名单 → OHPM registry 在线核验，假包当场拦截 |
| AI 写 `this.list.push(x)` 状态不刷新（**LLM 第一坑**） | UI 不更新，调试半小时才发现 | 钩子立刻报 `STATE-002 · High`，给改写示例 |
| AI 引用旧 API（DevEco 12 → 22 多次变化） | 用了已弃用的 `picker.PhotoViewPicker` | `ARKTS-DEPRECATED-PICKER` 即时拦截 + 给新 API |
| AGC 上架前才发现拒因 | 提审被打回再修 = 1 周 | 20 条 `AGC-RJ-*` 稳定 ID 编辑时就提示 |
| 多 AI 工具规则不一致（Claude / Cursor 各写一套） | 同一项目下 AI 给不同建议 | 单源 fan-out：5 个默认 SKILL → Cursor 6 个 `.mdc`（按 globs 触发）+ Copilot root < 4KB + `instructions/*.md` 按 applyTo 触发 |

---

## 使用方式 1：装进已有鸿蒙 app（推荐，30 秒）

```bash
# 1) 进你的鸿蒙 app 根目录
cd ~/WorkSpace/apps/my-harmony-app

# 2) 一行装好
npx -y harmonyos-ai-workspace

# 3) 启动你的 AI 助手——CLAUDE.md / AGENTS.md 自动加载
claude    # 或 codex / cursor
```

安装位置必须是**你的 app 根目录**，也就是能看到 `entry/`、`oh-package.json5`、`build-profile.json5` 的地方。安装器默认写入 Claude + Codex 规则；Cursor / Copilot 需要时用 `--targets` 打开。

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

安装后还会带上 AI 调试闭环脚本：

```bash
bash tools/harmony-dev-cycle.sh quick-check   # 轻量 ArkTS/OHPM 扫描
bash tools/harmony-dev-cycle.sh build-check   # ohpm install → codeLinter → build HAP
bash tools/harmony-dev-cycle.sh cycle-once    # build → install → run → 抓 8s hilog 给 AI
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

## 完整操作手册

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
│   CLAUDE.md / AGENTS.md / .agents/skills / .cursor/rules / …     │
│        │ AI 读到鸿蒙硬约束 + 9 SKILL 触发索引                    │
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
│   或：AI agent → tools/harmony-dev-cycle.sh →                    │
│       build-check / cycle-once / device-check → hilog → AI 分析  │
│       （完整闭环，详见 04-build-debug-tools/README §⚡️）          │
└──────────────────────────────────────────────────────────────────┘
```

详细工作流见 [`docs/USER-GUIDE.md` § 3](docs/USER-GUIDE.md)。AI agent 自治调试闭环
（让 Claude / Codex / OpenClaw 在终端完整跑 build→install→run→log，不再切 DevEco GUI）
见 [`04-build-debug-tools/README.md` §⚡️](04-build-debug-tools/README.md#%EF%B8%8F-ai-agent-自治调试循环脱离-deveco-gui-的-build--install--run--log)。

---

## 内置内容

| 资产 | 内容 |
| --- | --- |
| **AI 规则集** | `CLAUDE.md`（Claude Code）+ `AGENTS.md`（[agents.md 标准](https://agents.md/) 24+ 工具通用）+ 8 个按需触发的 [`.claude/skills/`](.claude/skills/) + Codex 镜像 [`.agents/skills/`](.agents/skills/) |
| **9 个 SKILL** | 5 个默认 fan-out（`arkts-rules` / `state-management` / `build-debug` / `signing-publish` / `runtime-pitfalls`，对所有项目通用）+ 4 个领域专项（`harmonyos-review` / `multimodal-llm` / `web-bridge` / `testing-quality`）；Claude Code 读 `.claude/skills/`，Codex 读 `.agents/skills/` |
| **PostToolUse 钩子链路** | Edit `.ets`/`.ts`/`oh-package.json5` 后自动跑 ArkTS 反模式扫描 + OHPM 包名核验 + 权限提示 |
| **多工具 fan-out** | 5 个默认 SKILL → Cursor 6 个 `.mdc`（按 globs 触发，单文件 < 12KB）+ Copilot root `< 4KB` + `.github/instructions/*.md` 5 个按 `applyTo` 触发 |
| **`doctor` 体检** | `npx harmonyos-ai-workspace doctor` 或 `bash tools/doctor.sh`：PASS/WARN/FAIL 三态报告，含钩子端到端自测（喂故意的 `STATE-002` 看是否被抓） |
| **CLI 工具集** | `install.sh`（manifest + sha256 安装）/ `run-linter.sh`（离线 codeLinter）/ `check-ohpm-deps.sh`（4 类校验）/ `check-rename-module.sh`（模块改名一致性）/ `test-suite.sh`（19 项回归断言）/ **`scaffold-deveco-project.sh`**（一键补 DevEco 脚手架 11 文件）/ **`harmony-dev-cycle.sh`**（`quick-check` / `build-check` / `cycle-once` / `device-check`，绕开 DevEco GUI Run 按钮） |
| **Recipe Templates** | 9 个可粘贴最小可用代码 — 基础 4 个：`permission/` / `list/` / `dark-mode/` / `login/`；进阶 4 个（OctoDesk 抽取）：`web-bridge-h5-shell/` / `llm-sse-client/` / `huks-secure-store/` / `scan-qrcode/`；测试 1 个：`hypium-uitest/` |
| **2026 提审 Top 20 拒因** | [`07-publishing/checklist-2026-rejection-top20.md`](07-publishing/checklist-2026-rejection-top20.md)，含 `AGC-RJ-001..020` 稳定 ID + 6 条高频项配可粘贴代码 |
| **Case Studies** | [`docs/case-studies/llm-chat-app.md`](docs/case-studies/llm-chat-app.md) — 真鸿蒙 LLM 对话 app M3-M13 实战（M3-M12 原始里程碑 + M13 运维期 layered icon / 9568297），12 节"症状/错误信息/修复 diff/教训"四段式 + [`docs/case-studies/android-parity-migration.md`](docs/case-studies/android-parity-migration.md) — paseo-harmony 14 阶段 Phase A/B 真修复笔记 |
| **测试 fixture** | 9 个回归 fixture 覆盖 inline 装饰器 / `@CustomDialog` / `@Reusable` / 普通工具类等边界 |
| **MCP** | `.mcp.json` 接通 Claude/通用 MCP；Codex 用 `bash tools/setup-codex-mcp.sh` 显式注册 `mcp-harmonyos` 到用户级配置；动作型 MCP 接入指引见 [`docs/MCP-INTEGRATION.md`](docs/MCP-INTEGRATION.md) |
| **可选官方文档镜像** | 5300+ 中文 + 5100+ 英文 OpenHarmony md（按需 `bootstrap-upstream-docs.sh -y` 拉，~2.7 GB） |

### 真正独有的能力（vs 同类项目）

PostToolUse 钩子并非孤例（[`yibaiba/harmonyos-skills-pack`](https://github.com/yibaiba/harmonyos-skills-pack) 也有 hooks），本仓库的真实差异点：

1. **OHPM 包名四类校验**（FAKE / NET / UNKNOWN / OK）+ registry openapi 在线核验 + 15s timeout —— [`tools/check-ohpm-deps.sh`](tools/check-ohpm-deps.sh)。同类无人做
2. **AGC 提审 Top 20 拒因稳定 ID 体系**（`AGC-RJ-001..020`）+ 高频项配可粘贴代码 —— `harmonyos-review` skill 与扫描器可用同一编号互引
3. **awk 装饰器上下文检测** + **inline-suppress** + **真 collapse 折叠** —— `tools/hooks/lib/scan-arkts.sh`，PrivateTalk 真工程实测假阳率 0%
4. **install/uninstall manifest + sha256** —— v0.4.0 起，用户原 `CLAUDE.md` 永不被吞，本工具写的所有文件可精确卸载
5. **OpenHarmony 官方文档镜像 bootstrap**（5300+ 中文 / 5100+ 英文 md 离线检索）+ **真鸿蒙 LLM Chat case study**（实战四段式）

完整对比见 [`docs/USAGE-GUIDE.md`](docs/USAGE-GUIDE.md) § B。

### 规则编号体系（精确说明）

本仓库的规则按用途分四层，**不应被合并表述为单一数字**：

| 层 | 数量 | 位置 | 用途 |
| --- | --- | --- | --- |
| **自动化扫描**（钩子触发） | 32 条 | `tools/hooks/lib/scan-arkts.sh` 内联 + awk 装饰器上下文检测 | grep-based 快扫，毫秒级反馈；支持 [inline-suppress](.claude/skills/arkts-rules/SKILL.md#抑制-scanner-误报inline-suppress) |
| **代码审查清单** | 75 条（10 大类） | `.claude/skills/harmonyos-review/references/checklist.md` | review skill 引用的稳定 ID（`SEC-001` / `STATE-002` / `TEST-002` 等） |
| **AGC 提审拒因** | 20 条 | `07-publishing/checklist-2026-rejection-top20.md` | 上架审核拒因映射，含 `AGC-RJ-*` 稳定 ID |
| **OHPM 黑名单**（已知伪包） | 28 项 | `tools/data/ohpm-blacklist.txt` + 脚本内联 | 防 AI 虚构包名 |

合计 ~155 个条目，分布在四层（scan 层与审查清单共用同一 ID 体系，部分编号重叠）；它们用于不同场景。

**接线层陷阱**（scanner 抓不到、灰度才暴露的）单独整理在 [`05-best-practices/bridge-integration-pitfalls.md`](05-best-practices/bridge-integration-pitfalls.md)：18 类常见 Web Bridge + 原生外壳集成坑（capability 握手 fail-closed、`javaScriptProxy` 生命周期、idempotencyKey 强制、envelope schema validation、token / SecureStore 写入原子性、pasteboard 提示时机、App-Linking 双侧配置 + EntryAbility 双入口、HMS ScanKit dual-import、原生 blur 有界增强、WebView 前后台生命周期统一管理、ArkWeb data-URL 下载、手机 WebView 软键盘 / visualViewport、移动 raw socket 边界、picker 上传 / RAG 真机验收等），沉淀自下游真工程教训。

**Monorepo 接入**：HarmonyOS shell 是大 monorepo 子目录的项目（不是 npm app 形态），参考 [`samples/integrations/monorepo-consumer/`](samples/integrations/monorepo-consumer/) —— 三个文件薄 wrapper、scope 到子目录、单一来源、零文件复制；包含 token 成本实测与降噪方案。

---

## 版本契约（Version Contract）

```yaml
# 鸿蒙系统侧（API 编号是单一权威，不同 API 对应不同 HarmonyOS 系统版本）
harmonyos_system:
  min_supported_api:        12   # API 12 = HarmonyOS 5（NEXT）时代起，本仓库规则适用最低线
  latest_release_api:       24   # API 24 = HarmonyOS 6.1.1，2026-05-26 Release（API/SDK/IDE 全 Release；ROM 推送以华为升级名单为准）
  widely_deployed_api:      23   # API 23 = HarmonyOS 6.1.0，2026-04-20 Release 起消费推送（Pura 系列首发）
  developer_preview_api:    26   # API 26 = HarmonyOS 7 Developer Beta1（2026-06-12 HDC 发布；注意官方跳过了 API 25 — 跑生产 app 别选）
  recommended_target:       23   # 新项目推荐 targetSDK（需要 API 24 新能力才上 24）
  recommended_min:          12   # 新项目推荐 minSDK

toolchain:
  deveco_studio:  ">= 6.1.0"     # 稳定线 6.1.1 Release；预览线 26.0.0 Beta1（版本号已切年份制，内置 Node 18 → 24）
  ohpm:           ">= 6.0"       # ohpm 6.x 起 `view` 子命令改名 `info`
  # ArkTS 无独立版本行：动态 ArkTS 随 SDK 走；ArkTS-Sta（`use static` 静态模式）仍在演进中，生产不用

ai_assistants:
  claude_code:    ">= 0.5"
  codex_cli:      ">= 0.1"
  cursor:         ">= 1.0"
  copilot:        "ChatGPT-class instructions OK"
  deveco_cli:     "可选；官方 @deveco/deveco-cli 与本仓工具互补（见 04-build-debug-tools）"

last_verified_docs_snapshot: "2026-07-09"
```

> **如何读这张表**：API 编号才是单一权威——HarmonyOS 5 = API 12+ 时代，HarmonyOS 6 = API 21–24，HarmonyOS 7 = API 26（无 25）。系统版本号 ↔ API 对照：`6.0.0=20（仅开发者版）· 6.0.1=21 · 6.0.2=22 · 6.1.0=23 · 6.1.1=24 · 7.0 Beta=26`。
>
> **生产应用选 API 23–24**（minSDK 12）；HarmonyOS 7 Developer Beta（API 26）当下仅尝鲜用。鸿蒙生态快速迭代：本仓库每次发版前在 `last_verified_docs_snapshot` 日期对齐一次版本现实。

---

## 其他接入方式

### curl 安装（不依赖 npm）

```bash
cd ~/WorkSpace/apps/my-harmony-app
curl -fsSL https://raw.githubusercontent.com/Octo-o-o-o/harmonyos-ai-workspace/main/tools/install.sh | bash
```

### clone 整个工作区（学习 / 贡献 / 维护规则）

```bash
git clone https://github.com/Octo-o-o-o/harmonyos-ai-workspace.git ~/WorkSpace/HarmonyOS_DevSpace
cd ~/WorkSpace/HarmonyOS_DevSpace
bash tools/bootstrap-upstream-docs.sh   # 拉 OpenHarmony 官方文档镜像（~2.7 GB，可选）
bash tools/verify-environment.sh        # 检查本机环境
```

适合：想系统学习鸿蒙、想让 AI 在本目录开发、想给本仓库贡献。

### monorepo 子目录接入

如果你的鸿蒙 shell 只是大仓里的一个子目录，不想把规则文件复制到仓库根目录，参考 [`samples/integrations/monorepo-consumer/`](samples/integrations/monorepo-consumer/)：用少量 wrapper 把 AI 上下文和扫描范围 scope 到 HarmonyOS 子项目，保留单一规则来源。

### 从零开始（macOS 干净状态）

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
7. **不要直接 import npm 包**：只能用 OHPM 上的包——TPC 官方移植版（如 `@ohos/axios`）与白名单化纯 JS 包（如 `dayjs`）真实存在，但**包名必须先在 <https://ohpm.openharmony.cn/> 核验**（`@ohos/dayjs`、`@ohos/uuid` 这类想当然的名字不存在）

完整版见 [`CLAUDE.md`](CLAUDE.md) 第 0、11、12、13 节 + 9 个 SKILL（按需触发）。

---

## 进阶 / 文档

- 📖 [使用说明书 USER-GUIDE.md](docs/USER-GUIDE.md) — 首次使用、日常工作流、典型任务、AI 协作魔法咒语
- 🛠 [进阶用法 USAGE-GUIDE.md](docs/USAGE-GUIDE.md) — 多 app 共享规则、三层发布策略、AI 启动姿势、与同类项目对比
- 🚀 [SETUP-FROM-SCRATCH.md](docs/SETUP-FROM-SCRATCH.md) — macOS 干净状态到第一行 `.ets` 跑通
- 🔌 [MCP-INTEGRATION.md](docs/MCP-INTEGRATION.md) — 接入第二个 MCP（动作型，hdc 控设备）
- 📋 [CLAUDE.md](CLAUDE.md) — Claude Code 项目级大宪章 + 9 SKILL 触发索引 + 目录全图
- 🤖 [AGENTS.md](AGENTS.md) — 跨工具通用宪法（24+ 工具兼容）
- 📜 [CHANGELOG.md](CHANGELOG.md) — 完整版本历史

---

## 关键事实（以版本契约为准）

- **最新 Release**：HarmonyOS 6.1.1 / **API 24**（2026-05-26；API/SDK/IDE 全 Release）
- **消费推送主力**：HarmonyOS 6.1.0 / **API 23**（2026-04-20 Release 起推送）
- **开发者 Beta**：HarmonyOS 7 / **API 26**（2026-06-12 HDC 发布；官方跳过 API 25）
- **新项目建议**：targetSDK API 23（要 API 24 新能力才上 24），minSDK API 12
- **API 20 是 2025-09-25 仅开发者版**，不要选作 targetSDK
- **主语言**：ArkTS（增强 TypeScript） / **UI**：ArkUI（声明式，V1 默认）/ **应用模型**：Stage（FA 已废弃）
- **包格式**：`.hap`（单 module）/ `.app`（应用包）/ `.har`（静态库）/ `.hsp`（共享库）
- **官方 AI 工具**：DevEco Code（鸿蒙 AI agent）/ DevEco CLI（`@deveco/deveco-cli`，构建原子能力）；与本仓库互补，见 [`04-build-debug-tools/README.md`](04-build-debug-tools/README.md)

---

## 贡献与反馈

- 贡献流程：[`CONTRIBUTING.md`](CONTRIBUTING.md)
- 版本历史：[`CHANGELOG.md`](CHANGELOG.md)
- 评审归档：[`docs/archive/reviews/`](docs/archive/reviews/) — 6 轮多视角评审 + PrivateTalk 真用户验收
- 发现规则错误 / 补 API / 加 Skill：欢迎 PR
- 找了一圈也没解决你的鸿蒙问题：开 issue，附 DevEco 版本、API Level、`hvigorw codeLinter` 输出

---

## 许可

- 本仓库自创内容（指南、`CLAUDE.md`、`AGENTS.md`、`.claude/skills/`、`.agents/skills/`、脚本、示例）：**MIT License**（详见 [`LICENSE`](LICENSE)）
- `upstream-docs/openharmony-docs/`（运行 bootstrap 拉取）：CC-BY-4.0，版权归 **OpenAtom Foundation / OpenHarmony 项目**

---

## 相关链接

- OpenHarmony 官网：<https://www.openharmony.cn/>
- 华为开发者联盟：<https://developer.huawei.com/consumer/cn/>
- DevEco Studio 下载：<https://developer.huawei.com/consumer/cn/deveco-studio/>
- DevEco CLI（官方 agent 工具链，可与本仓共存）：<https://www.npmjs.com/package/@deveco/deveco-cli>
- OHPM 包仓库：<https://ohpm.openharmony.cn/>
- Anthropic Claude Code 文档：<https://docs.claude.com/en/docs/claude-code>
- OpenAI Codex CLI：<https://github.com/openai/codex>
- AGENTS.md 跨工具规范：<https://agents.md/>
