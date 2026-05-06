# 实施方案 v1 · 让 AI 助手真正会写鸿蒙

> 2026-05-06 起草。本文档先**陈述真实需求**、再**列必须实施的能力**、再**剔除伪需求**，最后给**逐项验收标准**。
>
> 实施期间任何项被发现"做了反而碍事"，必须从清单中删除。**衡量标准是"用得顺"，不是"功能多"。**

---

## 一、最终目标（用户视角的成功定义）

一个鸿蒙开发者打开 Claude Code（或 Codex / Cursor / Copilot）开发自己的鸿蒙 app 时，**不读任何文档**，希望发生：

1. **AI 写出的 ArkTS 代码编译通过率显著提升**：基线（裸 LLM）= **3.13% Pass@1**（ArkEval / Claude 4.5 Sonnet），目标 ≥ 60%
2. **AI 不会调用不存在的 OHPM 包名**（已知问题：常虚构 `@ohos/xxx`）
3. **AI 写完 `.ets` 后立刻知道有没有 ArkTS 反模式**（不要等到 `hvigorw codeLinter` 才发现）
4. **AI 不会把状态变更写成就地 mutation**（42% 的 LLM 错误来源）
5. **跨 4 个主流工具（Claude Code / Codex / Cursor / Copilot）规则一致**——同一份源生成各自的配置文件
6. **从零到能开发**只用 1 条命令（`npx harmonyos-ai-workspace init`）

**反目标（明确不做）**：

- 不做 DevEco Studio 替代品（IDE 还得用 DevEco 跑 Inspector / Profiler / 模拟器 / 真机）
- 不做 11 个 AI 工具的 fan-out（Top 4 占 95% 用法，其余维护成本不值）
- 不做 16 个业务模块脚手架（业务变化快，模板老化快，DevEco 自带已够）
- 不做自己的 ArkTS 解析器 / 静态分析器（ArkAnalyzer / `hvigorw codeLinter` 已存在，调用即可）
- 不做自家微调模型（成本高、效果不可控、版本难维护）

---

## 二、真实需求 vs 伪需求（依据 2026-05 调研）

### 真需求（有数据支撑）

| 优先级 | 需求 | 证据 |
| --- | --- | --- |
| **P0** | DevEco 之外可用的 ArkTS 实时校验 | 多个 CSDN / 掘金帖：用 Cursor / Trae 写鸿蒙，"满屏血红" |
| **P0** | OHPM 包名校验 | Phodal: "ChatGPT 缺 HarmonyOS 最新生态知识"；常虚构 `@ohos/xxx` 包 |
| **P0** | 一行命令把规则装进 app 项目 | yibaiba 的 `npx` 安装器是 3 家中唯一被实际复用的安装方式 |
| **P0** | UI 状态失同步检测 | ArkEval：42% 错误来源；最高频反模式 |
| **P1** | 跨 AI 工具规则一致 | 团队混用 Claude / Cursor / Copilot 已成普遍；规则不同步导致代码风格分裂 |
| **P1** | 不依赖 DevEco 的 codeLinter 入口 | DevEco 6.x 启动慢、占内存；CI / git hook 场景需要 CLI 等价物 |
| **P1** | 中国市场提审 checklist | AGC 审核细节 AI 训练数据缺失；上架被拒原因高度本土化 |
| **P2** | 签名流程脚本化 | 签名"麻烦"是普遍痛点，但脚本化复杂度高，先观望 |

### 伪需求（看似有用但实际意义有限）

| 项 | 为什么不做 |
| --- | --- |
| 11 个 AI 工具配置 fan-out | Continue / Cline / Ollama / Windsurf 等使用率 < 5%；维护成本远超收益 |
| 16 个业务模块粘贴式模板 | 鸿蒙生态 6 个月迭代一次，模板 6 个月就过时；DevEco 自带模板已能覆盖典型场景 |
| 自家 ArkTS 静态分析器 | `hvigorw codeLinter` 已存在；ArkAnalyzer 已开源；自造重复 |
| 自家鸿蒙 LLM 微调模型 | 训练数据稀缺；微调成本几万到几十万；效果未必胜过给 Claude / Codex 加 RAG |
| 业务领域细分 SKILL（金融 / 医疗 / 游戏） | 长尾，写一次用一次；让用户自己派生 |
| Slack / Discord / 微信群运营 | 不是技术问题；先把工具做好 |

---

## 三、实施清单（按 ROI 排序）

### P0 — 必须做，立即开工

#### P0-1：PostToolUse 钩子 · ArkTS 实时反模式扫描

**它解决的问题**：AI 改完 `.ets`，编辑器（如 Cursor）报红错但用户不会跑 `hvigorw codeLinter`。需要在 AI 工具的"写文件"动作完成后**自动**触发扫描，把结果回喂给 AI 让它当场修。

**具体形态**：

```
.claude/settings.json
└── hooks
    └── PostToolUse
        └── matcher: "Write|Edit|MultiEdit"
            └── command: tools/hooks/lib/scan-arkts.sh

tools/hooks/
├── post-edit.sh                # 入口；解析 hook payload，分发扫描
└── lib/
    ├── scan-arkts.sh           # 60+ 编号反模式正则扫描
    └── parse-hook-input.sh     # 兼容 Claude / Codex / 其他 JSON 格式
```

**扫描规则**：复用 `.claude/skills/harmonyos-review/references/checklist.md` 的 60+ 编号规则；先实现 grep-based 快扫（< 200ms），未来可接 ArkAnalyzer。

**借鉴源**：`/tmp/harmonyos-research/harmonyos-skills-pack/skills/harmonyos-ark/hooks/`。

**验收**：在 Claude Code 内 Edit 一个含 `this.list.push(x)` 的 `.ets` 文件，钩子立即在 AI 上下文中输出 `[STATE-002 · High] 行 N: 就地 mutation 不触发重渲染，应改为 this.list = [...]`。

#### P0-2：OHPM 包名校验脚本

**它解决的问题**：AI 在 `oh-package.json5` 里加 `"@ohos/lottie-player": "^1.0.0"` —— 这个包根本不存在；编译失败之前用户没有反馈通道。

**具体形态**：

```
tools/check-ohpm-deps.sh
  · 读取 oh-package.json5
  · 对每个 dependency 调用 OHPM Registry API:
      curl -s https://ohpm.openharmony.cn/ohpm/v3/detail/<name>
  · 不存在的包打印 [FAKE] <name>，并提示可能的真实替代
  · 退出码非 0 时 hook 通过 stderr 回喂 AI
```

**集成进 PostToolUse**：当 AI Edit `oh-package.json5` 时同步触发。

**验收**：手动写一个不存在的包名，运行脚本立即报警 + 给出建议。

#### P0-3：CLI 安装器 · `npx harmonyos-ai-workspace init`

**它解决的问题**：用户已经有自己的鸿蒙 app 项目，**不想 clone 整个 DevSpace**——只要把规则装进自己的 app。

**具体形态**：

```
bin/cli.js               # ~150 行 Node.js（无依赖，纯 fs/child_process）
package.json             # 含 "bin": { "harmonyos-ai-workspace": "./bin/cli.js" }
```

**接口**：

```bash
# 默认装 Claude Code + Codex 两套（最常见组合）
npx harmonyos-ai-workspace@latest init

# 显式指定目标
npx harmonyos-ai-workspace init --targets=claude,codex,cursor,copilot
npx harmonyos-ai-workspace init --targets=claude       # 只装 Claude

# 中国镜像（GitHub 不通时）
npx harmonyos-ai-workspace init --mirror=ghproxy

# 卸载
npx harmonyos-ai-workspace uninstall

# 升级（覆盖时显式标记，避免误删用户改动）
npx harmonyos-ai-workspace upgrade --diff
```

**装到 app 项目里的内容**：

```
my-app/
├── CLAUDE.md                       # 软指针：'> 通用规则继承自 ...'
├── AGENTS.md
├── .claude/
│   ├── settings.json               # PostToolUse 钩子配置
│   └── skills/                     # 5 个 Skills
├── .cursor/rules/harmonyos.mdc     # 仅当 --targets 含 cursor
├── .github/copilot-instructions.md # 仅当 --targets 含 copilot
├── tools/hooks/                    # 钩子脚本（全平台通用）
└── .mcp.json                       # mcp-harmonyos 配置
```

**默认 Top 4 工具支持**：Claude Code / Codex CLI / Cursor / Copilot Coding Agent。其他工具（Windsurf / Gemini / Continue）通过 `--targets=...` 显式指定，**不默认装**。

**借鉴源**：`/tmp/harmonyos-research/harmonyos-skills-pack/bin/cli.js`（230 行，结构清晰），但**默认目标缩到 2 个**而非 3 个。

**验收**：在干净的鸿蒙 app 项目运行 `npx harmonyos-ai-workspace init`，启动 Claude Code 后能立刻引用规则；运行 `uninstall` 干净移除。

---

### P1 — 第二批，P0 跑通后再做

#### P1-1：单源 fan-out 脚本

**它解决的问题**：维护规则时只想改一处，自动同步到 Cursor / Copilot 等其他工具的约定路径。

**具体形态**：

```
tools/generate-ai-configs.sh
  · 输入：.claude/skills/*/SKILL.md  + AGENTS.md（已有）
  · 输出：
    .cursor/rules/harmonyos.mdc          # frontmatter + globs
    .github/copilot-instructions.md      # 全 markdown
    .windsurfrules                       # 纯文本兜底
  · 维持 Claude / Codex 路径不动（已是源）
```

**默认仅 4 工具，其他通过 `--include=continue,cline` 显式扩展。**

**验收**：改 `.claude/skills/arkts-rules/SKILL.md` 后跑脚本，三个目标文件内容同步。

#### P1-2：本地 codeLinter wrapper

**它解决的问题**：CI / git hook 场景需要不依赖 DevEco GUI 的 ArkTS 校验。

**具体形态**：

```
tools/run-linter.sh
  · 检测 PATH 中是否有 hvigorw（DevEco 装好就有）
  · 没有则尝试 ~/Library/Huawei/Sdk/<api>/openharmony/toolchains/hvigor
  · 跑 hvigorw codeLinter --watch=false
  · 解析输出，按规则编号汇总
  · 失败时 exit 1，便于做 pre-commit hook
```

**集成**：`tools/git-hooks/pre-commit` 调用此脚本；用户 `npx harmonyos-ai-workspace install-git-hooks` 启用。

**验收**：在装了 DevEco 的机器上跑 `tools/run-linter.sh` 等价于 IDE 的 codeLinter。

#### P1-3：中国市场提审 checklist

**它解决的问题**：AGC 审核细节本土化严重，AI 训练数据缺失。

**具体形态**：补 `07-publishing/checklist-2026.md`，含：

- 隐私政策必备字段（个人信息、第三方 SDK、跨境）
- 实名认证、ICP 备案、APP 备案要求
- 涉及金融 / 医疗 / 游戏 的特殊审核
- 激励 / 推送 / 后台执行权限的合规话术
- 真实拒因 + 修复案例

**验收**：内容 ≥ 50 条具体项，每条带"why"和"how"。

---

### P2 — 长期，可选

#### P2-1：扩展规则到 60+ 编号体系

把现有 25 条 TS→ArkTS 规则补到 ~60，每条带稳定 ID。已经在 review skill 中部分做到（9 大类 60+ 编号），需要把 `01-language-arkts/02-typescript-to-arkts-migration.md` 改成同样编号化。

**何时做**：等用过几个 PR 后看真实引用频率，再决定补哪些规则。

#### P2-2：项目模板（Layer 3）

跑通 1 个真 app 后，抽业务无关骨架到 `harmonyos-app-template` 独立仓库。**当前阶段不做**，避免与 DevEco 自带模板冲突。

#### P2-3：mcp-harmonyos 写侧能力

当前 `mcp-harmonyos` 是只读。借鉴 `XixianLiang/HarmonyOS-mcp-server`（Python，含 `aa start` / `hdc install` 等）写侧。**当前阶段不做**，等 P0/P1 跑稳。

---

## 四、不做清单（防过度设计）

每条都过审视："如果做了，谁会用？多久看一次？维护它要花多少时间？"

| 项 | 不做的理由 |
| --- | --- |
| 11 个 AI 工具 fan-out | Top 4 = 95% 用法；Continue/Cline/Ollama 维护成本远超收益 |
| 16 个业务模块粘贴模板 | 6 个月就过时；DevEco 自带模板已覆盖典型场景 |
| 自家 ArkTS 静态分析器 | hvigorw codeLinter / ArkAnalyzer 已存在 |
| 自家鸿蒙 LLM 微调 | 训练数据稀缺、成本高；给 Claude/Codex 加 RAG 性价比更高 |
| 业务领域细分 SKILL（金融 / 医疗 / 游戏） | 长尾；让用户自己派生 |
| 项目脚手架 | DevEco "New Project" 已经做得很好 |
| Slack / Discord 群运营 | 非技术问题；先把工具做好 |
| 自家 IDE 插件 | DevEco 自带 CodeGenie；JetBrains 有 AutoDev；VS Code 有 cheliangzhao 的 MCP；卷不动 |
| 翻译成英文 / 日文 | 鸿蒙生态 95% 在国内；先做好中文 |
| 给 GitHub Star 刷数 | 真用户口碑 > 表面数字 |

---

## 五、新增同类项目调研补充（2026-05 二轮）

| 项目 | URL | 关键发现 |
| --- | --- | --- |
| `baidu-maps/harmony-sdk-skills` | <https://github.com/baidu-maps/harmony-sdk-skills> | 官方 Baidu 出品，三 skill 拆分（SDK / 语言 / 空项目）；可借鉴拆分方式 |
| `cheliangzhao.arkts-language-support` (VS Code) | <https://marketplace.visualstudio.com/items?itemName=cheliangzhao.arkts-language-support> | **第二个 HarmonyOS MCP 服务**，含设备 / 项目 / 构建 / 部署查询，比 mcp-harmonyos 更丰富 |
| `ohosvscode/arkTS` (VS Code 插件) | <https://github.com/ohosvscode/arkTS> | LSP + codeLinter + 模拟器 / SDK / Hvigor 面板，最新 1.3.10（2026-05-02），但**无 AI 集成** |
| `Phodal/AutoDev` (JetBrains) | <https://www.phodal.com/blog/autodev-aigc-for-harmonyos/> | 最雄心勃勃的 AI-for-鸿蒙：PSI 抽象 + AutoArkUI 两步 RAG 代码生成 + Android→鸿蒙布局迁移 |
| `awesome-cursorrules` issue #62 | <https://github.com/PatrickJS/awesome-cursorrules/issues/62> | HarmonyOS 的 `.cursorrules` 提案 14 个月未合并 → **first mover 机会仍在** |
| `hreyulog/embedinggemma_arkts` (HuggingFace) | <https://huggingface.co/hreyulog/embedinggemma_arkts> | 第一个 ArkTS 微调嵌入模型 + 数据集；可作为 RAG 层 |
| `sqlab-sustech/hmtest` | <https://github.com/sqlab-sustech/hmtest> | RL 驱动鸿蒙自动测试，集成 ArkAnalyzer |
| `craftysecurity/HAP-Tool` | <https://github.com/craftysecurity/HAP-Tool> | Python 脚本化签名 / 安装；可作为 P2-3 签名脚本起点 |

**结论强化**：

- "AI 助手 + HarmonyOS" 领域**没有任何项目**实现了 P0-1 的 PostToolUse 钩子 + P0-3 的 npx 一行装 + P1-1 的 4 工具同步——本仓库做了就是首个真正端到端的方案。
- 已有的 VS Code / JetBrains 插件都是 IDE 内嵌方案，**对 Claude Code / Codex CLI 用户毫无帮助**——本仓库填的正是这个空白。
- HuggingFace 的 ArkTS 嵌入模型是未来 RAG 升级的好材料，但**当前阶段不集成**（需要本地向量库基础设施）。

---

## 六、施工后的真实使用流程（设计验证）

实施完成后，用户的体验应是：

```bash
# Day 0: 用户已有 my-music-player 鸿蒙 app
cd ~/Workspace/my-music-player

# Day 0: 一行装好 AI 规则
npx harmonyos-ai-workspace@latest init
# → 默认装 Claude Code + Codex
# → .claude/skills/、CLAUDE.md、AGENTS.md、.mcp.json、tools/hooks/ 一次到位

# Day 1: 写新功能
claude
# > "帮我加一个播放历史页面，用 LazyForEach"
# AI 写了 entry/src/main/ets/pages/History.ets
# ↓ Edit 工具完成的瞬间，PostToolUse 钩子触发
# ↓ tools/hooks/lib/scan-arkts.sh 跑完，输出回喂给 AI:
# "[STATE-002 · High] line 28: this.history.push(item) 不触发重渲染。
#  请改为 this.history = [...this.history, item]"
# ↓ AI 看到反馈，立即自我修正
# 用户最终拿到的是规则正确的代码

# Day 2: AI 想用某个不存在的包
claude
# > "加 lottie 动画"
# AI 写了 oh-package.json5 加 "@ohos/lottie-player": "^1.0.0"
# ↓ Edit 触发钩子，tools/check-ohpm-deps.sh 跑
# ↓ 输出: [FAKE] @ohos/lottie-player 在 OHPM Registry 不存在
#         可能你想要: @ohos/lottie (real) 或 自行从 GitHub fork
# ↓ AI 修正

# Day 3: 同事用 Cursor
cd ~/Workspace/my-music-player
npx harmonyos-ai-workspace init --targets=cursor
# → 已装的 Claude/Codex 配置不动；新增 .cursor/rules/harmonyos.mdc
# 同事在 Cursor 中享受同样规则

# Day 30: 上游规则升级
npx harmonyos-ai-workspace upgrade --diff
# → 显示对比，让用户决定哪些覆盖
```

---

## 七、初版交付里程碑

| 里程碑 | 交付物 | 验收 |
| --- | --- | --- |
| **M1（本周）** | P0-1 钩子 + P0-2 OHPM 校验 + P0-3 CLI 安装器 | 在我自己的 macOS 上能 `npx . init` 装到测试 app，钩子触发后 AI 真能自我修正 |
| **M2（M1 + 1 周）** | P1-1 fan-out + P1-2 codeLinter wrapper + 中国镜像兜底 | 改一处规则，4 工具配置同步；离线 codeLinter 工作 |
| **M3（M2 + 2 周）** | npm 发布 v0.1.0 + 一个真鸿蒙 app demo + GitHub Release | 任何人 `npx harmonyos-ai-workspace init` 跑通 |
| **M4（社区反馈）** | P1-3 提审 checklist + bug fix + 真实用户案例 | 有 5+ 真用户反馈，修过 3+ issue |

---

## 八、Review · 防过度设计自查

每实施一项前，都要回答：

1. **谁会用它？** 想象不出 3 个真实使用场景就不做
2. **它解决的问题是真的吗？** 没有 CSDN / Issue / 论坛证据就不做
3. **维护成本？** 估计每月维护时间，超过 1 小时就要权衡
4. **同等效果有没有更轻方案？** 能用 grep 解决就不写 AST 解析

**当前 P0/P1 的过度设计风险点**：

- ⚠️ **CLI 安装器**可能过度——可考虑先只提供 `tools/install.sh` 让用户 `curl ... | bash`，等用户多了再做 npm 包。**决议：v0.1 先提供 install.sh，v0.2 升级 npm 包；这样 M1 工作量减半。**
- ⚠️ **fan-out 4 个目标**可能过度——v0.1 先只做 Cursor（issue #62 证明刚需）；Copilot / Windsurf 等用户提需求再加。**决议：v0.1 仅 fan-out 到 Cursor，其他延后。**
- ⚠️ **中国市场 checklist** 50 条门槛太高——降到 20 条核心 + 链接到官方原文。**决议：聚焦"高频拒因 Top 20"。**

---

## 九、最终 P0 / P1 缩水版（实际开始施工的清单）

| ID | 任务 | 工作量 | 依赖 |
| --- | --- | --- | --- |
| **P0-A** | `tools/hooks/lib/scan-arkts.sh` + `.claude/settings.json` PostToolUse 配置 | 半天 | 无 |
| **P0-B** | `tools/check-ohpm-deps.sh` | 2 小时 | curl |
| **P0-C** | `tools/install.sh`（curl pipe-able） + 文档说明 | 半天 | 无 |
| **P0-D** | 钩子在 Claude / Codex 不同 hook payload 下的兼容（统一 parser） | 2 小时 | P0-A |
| **P1-A** | `tools/generate-ai-configs.sh` 仅 fan-out 到 Cursor `.mdc` | 3 小时 | 无 |
| **P1-B** | `tools/run-linter.sh` 包装 hvigorw codeLinter | 2 小时 | DevEco 已装 |
| **P1-C** | `07-publishing/checklist-2026-rejection-top20.md` | 半天 | 调研 |
| **P2-（待）** | 升级 install.sh 到 npm 包；fan-out 加 Copilot；扩展规则编号 | 视反馈定 | 真用户 |

**P0 总工作量约 1.5 天；P1 约 1 天；M1 + M2 ≈ 3 天可达可发布状态。**

---

## 十、施工后第一时间需要回答的"成功问题"

发布 v0.1 后第一周内通过自用 + 至少一个测试用户验证：

- [ ] 我自己开一个鸿蒙 app（纯新项目），`curl install.sh | bash`，启动 Claude Code 后 5 分钟内写出第一个能跑的页面，且 AI **没有**违反任何 ArkTS 硬约束
- [ ] 故意让 AI 写 `this.list.push(x)`，PostToolUse 钩子能在 1 秒内反馈
- [ ] 故意让 AI 写一个虚构的 OHPM 包名，校验脚本能在 3 秒内反馈
- [ ] 在 Cursor 中打开同一项目，规则被正确加载（`.cursor/rules/harmonyos.mdc` 起作用）
- [ ] 一个不会鸿蒙的同事 / AI 助手按 README 操作 1 小时内能跑通

**任何一项不达标，就是设计或实施缺陷，必须修到达标再算 v0.1 完成。**

---

## 十一、二次 review · 第一遍漏掉的事

写完一遍后回头审视，发现以下 4 个缺漏 / 假设错误：

### 11.1 PostToolUse 钩子是 Claude Code 独有

**原假设**：钩子能给所有 4 个工具用。**实际**：

| 工具 | hook 等价物 | 强制力 |
| --- | --- | --- |
| Claude Code | `.claude/settings.json` 的 `hooks.PostToolUse` | **强制**（每次 Edit/Write 后 100% 触发） |
| Codex CLI | 仅 `AGENTS.md` 约束 + 模型主动读 | 劝告性（依赖模型遵守） |
| Cursor | `.cursor/rules/*.mdc` + glob | 劝告性 |
| Copilot Coding Agent | `.github/copilot-instructions.md` | 劝告性 |

**纠正**：PLAN 不应该承诺"所有工具实时校验"。改成：

- **Claude Code 用户享受强校验**（钩子）
- **其他工具用户享受规则引导**（rules 文件 + AGENTS.md）+ **手动跑** `tools/run-linter.sh` / `tools/check-ohpm-deps.sh`

这是工具能力差异，不是设计缺陷。但 README / 文档必须**说清楚**，避免用户预期错位。

### 11.2 钩子的"反馈通道"需要明确

**原假设**：钩子打到 stderr 就行。**需要查证**：

- Claude Code 默认会把 hook stderr 注入下一次 AI 上下文吗？
- 如果不会，AI 看不到反馈，钩子就只是给"人"看的（依然有用，但没那么神奇）。

**决议**：
- 钩子**先打到 stderr**（人能看见）
- 同时**写入** `.claude/skills/.last-scan-result.txt`，并在 `CLAUDE.md` 里加一句"如果 `.claude/skills/.last-scan-result.txt` 存在且非空，先读它再继续"——这样下次 AI Edit 前会读到上次结果
- 长期：等 Claude Code SDK 提供更好的 hook→context 注入再升级

### 11.3 用户的 OS 多样性

**原假设**：macOS 优先即可。**实际**：

- DevEco Studio for Windows 是主流（华为开发者 70%+ 在 Windows）
- 但 Claude Code / Codex CLI 在 Windows 上是 WSL2 + bash，bash 脚本能跑
- Native PowerShell 用户先延后，文档里建议 "在 WSL 中使用"

**决议**：v0.1 仅 macOS / Linux / WSL（bash）；Windows native PowerShell 等真有人提需求再做。

### 11.4 自我测试 fixture 缺失

**原假设**：去用户的鸿蒙项目测。**实际**：我自己手上没有完整鸿蒙项目可测，钩子和校验脚本需要 `.ets` 反模式样本来回归。

**决议**：v0.1 自带 `tools/hooks/test-fixtures/` —— 几个故意写得"不对"的 `.ets` 文件，让钩子能 grep 出已知问题。这样：

- 仓库内 CI 能跑
- 新 contributor 改钩子时能立即知道有没有跑挂
- 用户拿到也能 `bash tools/hooks/lib/scan-arkts.sh tools/hooks/test-fixtures/Bad.ets` 验证

### 11.5 v0.1 出口标准重申

经二次 review 调整，v0.1 的承诺**显式缩窄**为：

| 能力 | Claude Code | Codex / Cursor / Copilot |
| --- | --- | --- |
| 规则注入 AI 上下文 | ✅ 自动（CLAUDE.md + Skills） | ✅ 自动（AGENTS.md / .cursorrules） |
| Edit 后实时校验 | ✅ 钩子触发 | ❌ 需手动跑 `tools/check.sh`（可加 git pre-commit） |
| 反馈到下一轮 AI 上下文 | ⚠️ stderr + last-scan 文件兜底 | — |
| 多工具规则同步 | ✅ fan-out 脚本 | ✅ |
| 一行安装 | ✅ install.sh | ✅ |
| OHPM 包名校验 | ✅（钩子触发 + 手动 CLI） | ✅（手动 CLI / git pre-commit） |

这就是"鸿蒙开发者 + AI 助手"目前在 2026-05 时间点能拿到的最完整方案——再追求"完美"会落入过度设计。

---

## 十二、立刻开始施工的清单（v0.1 缩水后）

按依赖关系编号：

```
0. 自带 tools/hooks/test-fixtures/ 几份故意写错的 .ets 用于测试
1. tools/hooks/lib/parse-hook-input.sh        # 解析 Claude/Codex hook stdin JSON
2. tools/hooks/lib/scan-arkts.sh              # 60+ 编号规则的 grep 集合
3. tools/hooks/post-edit.sh                   # 入口，调 1+2，写 .last-scan
4. .claude/settings.json                      # PostToolUse 配置
5. tools/check-ohpm-deps.sh                   # OHPM Registry 单包查询
6. tools/run-linter.sh                        # 包装 hvigorw codeLinter
7. tools/install.sh                           # curl-pipeable 安装到 app
8. tools/generate-ai-configs.sh               # SKILL.md → .cursor/rules/harmonyos.mdc
9. 07-publishing/checklist-2026-rejection-top20.md
10. README、CLAUDE.md、AGENTS.md 同步指向以上脚本
```

按顺序施工，每步可独立测试。完工后 v0.1 即达标。

---

## 十三、二轮精简（v0.2 发布前最后一次去过度设计）

P0+P1 实现完后做了一次 "刀刀见骨" 审视。结论：5 处真过度设计已修，3 处临界保留：

### 已精简（A 类）

| 项 | 修改 |
| --- | --- |
| **A1** · 三份策略/调研文档大量重叠（PLAN+OPEN-SOURCE-STRATEGY+RESEARCH-NOTES = 934 行） | OPEN-SOURCE-STRATEGY 改为高层抽象（~50 行）+ 指针；RESEARCH-NOTES 改为档案存根（~30 行）+ 指针；**PLAN.md 是唯一权威** |
| **A2** · `generate-ai-configs.sh` 是"假 fan-out"（heredoc 手写规则） | **改为真读 `.claude/skills/*/SKILL.md` + AGENTS.md 拼接**——改 SKILL.md 即可同步 Cursor/Copilot 配置，不用记着改两份 |
| **A3** · `samples/test-fixture/` 命名误导（不是 sample 而是钩子回归 fixture） | 移到 `tools/hooks/test-fixtures/`，所有引用同步更新 |
| **A4** · `CHANGELOG.md` Unreleased 把每个工具罗列一遍（复述 README） | 缩为简版 + 链到 PLAN.md |
| **A5** · `08-resources-links/` 跟 README "相关"段大量重复 | 顶部加导引"基础链接见根 README，本文是扩展资源详单"，删掉重复入口；保留差异化扩展（镜像、跨平台、社区论坛、设计资源） |

### 临界保留（B 类，理由清楚）

- **5 个 SKILL.md 跟主题目录 60-80% 重叠** —— 保留：Claude Skills 的设计哲学就是"中等卡片自动按需加载"，删了反而失去价值
- **`harmonyos-review/references/official-docs.md` 跟 CLAUDE.md § 4 重叠** —— 保留：审查场景下需要专属 doc 路径列表
- **`09-quick-reference/README.md` 跟 CLAUDE.md 装饰器表重叠** —— 保留：09 是"快速 lookup"，CLAUDE 是"宪法约束"，定位不同

### 不精简（C 类，必要）

- 主题目录 02-06 单 README ✓（AI 路由依赖）
- 钩子内 13 条规则 ✓（grep 实际能力子集）
- 8 个 tools/ 脚本 ✓（各司其职）
- 上游文档镜像 + bootstrap ✓（核心差异化）

### 收益

- 文档总量从 ~1500 行（PLAN+OPEN-SOURCE-STRATEGY+RESEARCH-NOTES）减到 ~600 行（PLAN）+ 80 行指针
- 单源 fan-out 真正成立——改 SKILL.md 后跑脚本，Cursor/Copilot 配置自动同步
- 命名一致：fixture 在工具目录、samples 留给真示例

