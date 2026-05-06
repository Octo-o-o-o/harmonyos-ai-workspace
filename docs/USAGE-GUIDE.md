# Usage Guide · 进阶使用方式

> README 只讲"装上能用"。本文档讲**怎么把工作区融进自己的开发节奏**。
>
> 简单情况下你**不需要读这份**——README 用法 A 一行 curl 装好就直接能用。

---

## A. 个人自用（开发自己的鸿蒙 app）

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

> 通常情况下用 README 用法 A（`tools/install.sh`）一行装到 app 项目即可，不需要软链；上面三种方式是"管理多个 app 项目时的共享方案"。

**启动 AI 工具的两种姿势**：

```bash
# 学习 / 改文档 / 给本仓库贡献
cd ~/WorkSpace/HarmonyOS_DevSpace && claude

# 实际开发功能
cd ~/WorkSpace/apps/my-music-player && claude
# Claude 自动读本目录的 CLAUDE.md，并能用 Bash 工具读 ../../HarmonyOS_DevSpace/...
```

**Codex CLI 同理**——在 app 根放 `AGENTS.md`（软链或独立写）即可。Codex 默认会从 git root 向上查找 `AGENTS.md`，并支持 `~/.codex/AGENTS.md` 全局兜底。

---

## B. 与已有同类项目的差异化

截至 2026-05，GitHub 上有几个相邻项目：

| 项目 | 形态 | 与本仓库的差异 |
| --- | --- | --- |
| `DengShiyingA/harmonyos-ai-skill` | 单源文件 → 11+ AI 工具配置生成器 | 他们偏"配置导出器"；本仓库是**结构化工作区**（含分类目录 + 上游文档镜像 + Skills + 脚手架 + Edit-时钩子） |
| `yibaiba/harmonyos-skills-pack` | npm 包 + 三目录同时部署 | 他们偏"上架 / 模块模板"；本仓库覆盖**语言迁移 + 状态管理 V1/V2 + 构建/调试/签名 + Edit-时钩子**全链路 |
| `CoreyLyn/harmonyos-skills` | 较小的 Agent Skills | 体量与覆盖面都小一档 |
| `aresbit/arkts-dev-skill` | 单 SKILL.md | 仅 ArkTS 语法层 |
| `baidu-maps/harmony-sdk-skills` | 三 skill 拆分（含 SDK 用法） | 绑定百度地图域；本仓库通用 |
| `XixianLiang/HarmonyOS-mcp-server` | Python MCP（动作型） | 跟本仓库互补——他们做 hdc 控设备，本仓库做规则 + 校验 |

如果你要做的是"可重用的 AI Skill 包"，上述项目可参考；本仓库的差异点在于**完整工作区 + 官方文档镜像 + Edit 后钩子 + 三层发布策略**——先是给 AI 看的"百科全书 + 实时校验"，再衍生出 Skill / 模板。

---

## C. 三层发布策略（开源给其他开发者）

```
┌──────────────────────────────────────────────────────────────┐
│ Layer 1 · harmonyos-ai-workspace  ← 本仓库                   │
│ 形态：参考工作区（规则 + Skills + 钩子 + 文档镜像 + 脚手架）│
│ 受众：希望用 Claude/Codex/Cursor 开发鸿蒙的工程师             │
│ 安装：curl install.sh | bash    或    git clone              │
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

**当前版本已完成 Layer 1**。Layer 2 的 Skill 文件已在 `.claude/skills/`，未来抽出独立仓库即可。Layer 3 等跑通 1 个真 app 后再做。详细路线图见 [`OPEN-SOURCE-STRATEGY.md`](OPEN-SOURCE-STRATEGY.md) 与 [`PLAN.md`](PLAN.md)。
