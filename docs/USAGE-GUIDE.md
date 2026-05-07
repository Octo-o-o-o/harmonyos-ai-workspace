# Usage Guide · 进阶使用方式

> **三份文档的关系**：
> - [`README.md`](../README.md) — 第一屏：装好 + 5 分钟验证
> - [`USER-GUIDE.md`](USER-GUIDE.md) — 使用说明书：日常工作流、典型任务、AI 协作魔法咒语、卸载升级
> - **本文档** — 进阶：多 app 共享规则、三层发布策略、AI 启动姿势、与同类项目对比、任务请求模板
>
> **简单情况下你不需要读这份**——README + USER-GUIDE 已经覆盖 95% 场景。本文档是给"想把工具融进团队节奏 / 想 fork 维护自家版本 / 想了解项目在生态里的位置"的人。

---

## 任务请求模板（贴给 AI 参考）

让 AI 一次写对鸿蒙代码的关键是把约束讲清楚。下面这个模板可以直接复制粘贴到对话开头：

```
请按以下约束在 [文件路径] 写/改 [功能描述]：

约束：
- HarmonyOS 6（targetSDK API 21 / 6.0.1，minSDK API 12），ArkTS + ArkUI 声明式
- 装饰器系列：V1（或 V2，二选一，不混用）
- import 走 @kit.*（不用 @ohos.* 旧式）
- 严格遵守 ArkTS 规则（禁 any / var / 解构 / 索引访问 / 对象字面量无注解 / for-in / delete 等）
- 状态变更必须替换引用（this.list = [...this.list, x]，不要 this.list.push(x)）
- 不要发明 API；查 upstream-docs/openharmony-docs/zh-cn/application-dev/reference/ 验证
- 不要发明 OHPM 包名；本仓库 tools/check-ohpm-deps.sh 会自动校验

期望产出：
- 新建 / 修改的文件清单
- 完整可粘贴的 .ets 代码
- 需要在 module.json5 加的权限
- 路由：在 main_pages.json 加什么
```

> Claude Code 用户：模板里的约束已经通过 `CLAUDE.md` + `.claude/skills/` 自动加载，不需要每次重复。这个模板适合**用别的 AI 工具**（如 ChatGPT 网页 / 文心 / Kimi）做单次问答时贴在 prompt 顶部。

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
