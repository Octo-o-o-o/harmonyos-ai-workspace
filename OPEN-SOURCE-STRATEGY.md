# 开源策略

> 本仓库的施工方案、不做清单、同类项目调研全部沉淀在 [`PLAN.md`](PLAN.md)。本文件只列**最高层抽象**——便于在 README 中引用。

## 核心定位

> **不是另一个 "AI 工具配置导出器"，也不是另一份 Skill 包，而是给 AI 助手用的"鸿蒙开发心智模型 + 上游文档 + Skills + 钩子"工作区**——它先是百科全书，再衍生出可重用的 Skill 包和项目模板。

## 三层发布

```
Layer 1 · harmonyos-ai-workspace（本仓库）
  形态：参考工作区（规则 + Skills + 钩子 + 文档镜像 + 脚手架）
  受众：希望用 Claude Code / Codex / Cursor / Copilot 开发鸿蒙的工程师
  安装：curl install.sh | bash    或者    git clone

       ↓ 抽规则                    ↓ 抽骨架

Layer 2 · claude-code-harmonyos-skills          Layer 3 · harmonyos-app-template
  形态：可重用 Claude Plugin                       形态：DevEco 可直接打开
  安装：/plugin install ...                       安装：degit your/template my-app
  时机：Layer 1 跑稳，社区有真用户后再独立            时机：跑通 1 个真鸿蒙 app 后再做
```

**当前进度**：Layer 1（本仓库）即将发布 v0.2.0（含 P0+P1 全套工具）。Layer 2 / 3 等真用户反馈再启动。

## 与已有同类项目的关系

调研详细见 [`PLAN.md` § 五](PLAN.md)。一句话：

- `DengShiyingA/harmonyos-ai-skill`：单文件 + 11 工具 fan-out（适合"配置导出"场景，已停更）
- `yibaiba/harmonyos-skills-pack`：npm 包 + 三目录三装（适合"被装到 app"场景，竞品最强）
- `CoreyLyn/harmonyos-skills`：薄 skill 集合
- 本仓库差异：**"工作区 + 上游文档镜像 + 钩子 + Skills + 提审清单 + bootstrap"**端到端方案

## 个人工作流（自用）

详见 [`README.md` § 推荐使用方式 A](README.md)。要点：

```
~/WorkSpace/
├── HarmonyOS_DevSpace/        ← 本仓库 clone（参考库）
└── apps/
    └── my-music-player/       ← 真业务 app（用 install.sh 装规则）
```

**不要**把真业务 app 放进本仓库的 `samples/`。
