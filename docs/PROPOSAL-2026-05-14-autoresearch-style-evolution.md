# Proposal: autoresearch 启发式的 DevSpace 自动进化

> **状态**: Draft / Discussion · 2026-05-14
> **背景**: 用户在 OctoDesk Mobile Companion 实战中提问：DevSpace 能否参考 [karpathy/autoresearch](https://github.com/karpathy/autoresearch) 自动升级进化？
> **结论先行**: 部分可以、且应该；部分不能、强行套会让仓库变烂。下面分组件诚实判断。

## 0. autoresearch 的核心机制是什么

不是"自己写代码"那么简单。它的 3 个工程约束才是关键：

1. **单文件 mutation scope**：agent 只能改 `train.py`。`prepare.py`（数据 / tokenizer / 评测）冻结。
2. **单一标量 fitness**：`val_bpb`（validation bits-per-byte），越低越好、vocab-size-independent，可跨架构公平比较。
3. **固定时间预算 + git 当实验日志**：每次实验固定 5 分钟，结果好 `git commit` 留下、不好 `git reset` 丢弃；results.tsv 是 untracked 实验流水账。

辅助但同样重要的：
- 人写的 `program.md` 是策略层，agent 不改
- "Simplicity criterion"——同样效果时偏好更简单的代码（防止 agent 把代码改成不可读）
- "NEVER STOP"——明确告诉 agent 主管在睡觉，别问"要继续吗"

要复制这套到 DevSpace，**关键是找到 DevSpace 自己的 `val_bpb`**。没有这个，套结构是徒劳。

## 1. DevSpace 各组件适用性体检

按"能不能定义客观 fitness + 能不能限制 mutation scope"两条线评估：

| 组件 | 客观 fitness 能否定义 | mutation 风险 | 适配 autoresearch 的程度 |
|------|---------------------|--------------|----------------------|
| **A. `tools/hooks/lib/scan-arkts.sh` lint 规则** | ✅ 可以（F1 在标注语料上） | 可控（单文件） | **高 ✅** |
| **B. `samples/templates/*` 范例** | ✅ 部分（compile + scan-arkts clean） | 中（agent 可能引入误导范式） | **中 ⚠** |
| **C. `upstream-docs/openharmony-docs/` 镜像** | ✅ 完全（== upstream git HEAD） | 低（git pull 即可） | **不适配**（这是 cron，不是探索） |
| **D. `tools/check-ohpm-deps.sh` 黑名单** | ⚠ 弱（依赖 ohpm CLI 网络查询） | 中 | 低 |
| **E. `00-09/` 分类知识库** | ❌（LLM-as-judge "更清晰吗"是漂移信号） | 高（agent 会过度优化措辞） | **不适配** |
| **F. `tools/install.sh` / `doctor.sh` 等基础设施** | ❌（"是否更稳"无标量度量） | 极高（破基础设施成本巨大） | **强烈不适配** |
| **G. `CLAUDE.md` / `AGENTS.md` AI 指令** | ❌（fitness 是下游 agent 行为，反馈环极长） | 高 | **不适配** |

**结论**: 真正能套 autoresearch 的是 **A（lint 规则）**，其次是 **B（范例）**。其他组件硬套会让 DevSpace 退化。

## 2. MVP 提案：`autolint` —— scan-arkts 规则进化循环

### 2.1 仿照 autoresearch 的 3 文件结构

DevSpace 已有的部分（不改）：

| autoresearch 角色 | DevSpace 对应物 | 状态 |
|------------------|----------------|------|
| `prepare.py`（冻结评测） | `tools/autolint/evaluate-lints.sh`（**待写**） | TODO |
| `train.py`（agent mutable） | `tools/hooks/lib/scan-arkts.sh` + `tools/autolint/candidate-rules.sh`（**待拆**） | TODO |
| `program.md`（人写策略） | `tools/autolint/PROGRAM.md`（**待写**） | TODO |
| `results.tsv`（实验日志） | `tools/autolint/results.tsv`（gitignored） | TODO |

新增目录：

```
tools/autolint/
├── PROGRAM.md              # 人写：agent 策略 + 边界
├── evaluate-lints.sh       # 冻结：evaluator
├── corpus/
│   ├── positives/          # 含已知反模式的 .ets 片段（label: rule-ID）
│   │   ├── arkts-001-any.ets
│   │   ├── state-002-array-mutation.ets
│   │   └── ...
│   ├── negatives/          # 干净 .ets（不应触发任何规则）
│   │   ├── good-prefstore.ets
│   │   └── ...
│   ├── holdout-positives/  # 测试集：训练时不可见
│   └── holdout-negatives/
└── results.tsv             # 实验流水（untracked）
```

### 2.2 fitness function

借鉴 `val_bpb` 的"单一标量 + vocab-independent"思路：

```
F1_holdout = 2 * precision_holdout * recall_holdout / (precision_holdout + recall_holdout)

complexity_penalty = max(0, (loc_after - loc_before) / 100) * 0.005
                     # 每多 100 行扣 0.005 F1

latency_penalty = max(0, (ms_per_scan_after - 50) / 1000)
                  # 单文件扫描超 50ms 开始扣
```

**fitness = F1_holdout - complexity_penalty - latency_penalty**

类似 autoresearch 的"Simplicity criterion"——同 F1 时偏好更简单的规则；规则越复杂、扫描越慢、代价越高。

### 2.3 实验循环

```
LOOP FOREVER:
  1. 读最近一周 OctoDesk apps/harmonyos/ 的 git log（外部信号源）
     找：(a) 新增的 // scan-ignore: 注释——可能是误报
        (b) 没被 scan-arkts 抓到但 PR review 改的代码——可能是漏报
  2. 选一个候选改动：加规则 / 调阈值 / 紧约束 / 放宽白名单
  3. 改 tools/hooks/lib/scan-arkts.sh（或 corpus/ 加 fixture）
  4. git commit
  5. 跑 tools/autolint/evaluate-lints.sh
     输出固定格式：
       fitness:       0.872400
       f1_holdout:    0.875000
       precision:     0.910
       recall:        0.842
       loc_delta:     +12
       scan_ms_p50:   38
  6. results.tsv 追加一行
  7. fitness 升 → keep；持平 → 看 LOC 是不是降了（简化也算赢）；降 → git reset
  8. 没收敛？跳回 1
```

### 2.4 反馈数据从哪来——比纯静态语料好的活水源

**OctoDesk 的 PostToolUse hook 已经在跑**——可以加一个 telemetry sink，把 hook 触发的事件流脱敏后写到本地 JSONL：

```
{
  "ts": "2026-05-14T10:23:11Z",
  "rule": "ARKTS-003",
  "file_hash": "sha256(content)",   // 不存原文，存哈希
  "violation_count": 7,
  "subsequent_edit_within_5min": true,
  "violation_count_after": 2,        // 触发后的命中数变化
  "scan_ignore_added": false
}
```

聚合后回答：
- **真阳率高的规则**：触发后业务 commit 减少违规数 → 这条规则在引导真改动
- **疑似误报**：高频 `scan_ignore_added: true` → 用户在主动抑制
- **死规则**：从不触发 → 模式过窄或场景已消失

这比合成 corpus 信号强很多。corpus 是静态、人工标的，活水 telemetry 反映真实工程偏好。**仿照 autoresearch 用 git history 当过去实验存档** —— 这里我们用 PostToolUse 事件流当过去实验存档。

### 2.5 怎么启动 / 估算成本

**Bootstrap（一次性，~3 人天）**:
1. 标注 corpus：30-50 个 positive ets fixture（每个 200 行内）+ 30-50 个 negative。从现有的 `tools/hooks/test-fixtures/` 和 `samples/templates/` 抽。
2. 拆 holdout：corpus 20% 留作 holdout，agent 不可见。
3. 写 `evaluate-lints.sh`：跑 scan-arkts on corpus，输出 fitness 格式。
4. 写 `PROGRAM.md`：策略 + 边界（不允许改 evaluate-lints 本身、不允许改 corpus、单次改动 < 50 行）。

**运行成本**:
- 每轮 ~10s（grep 扫 100 个文件）— 比 autoresearch 的 5 分钟训练快 30x
- 一晚跑 ~3000 次实验是可能的，但 95% 是没意义的微调
- 真实建议：每周触发 1-2 次，每次 30-60 分钟、产出 2-5 条规则改动让人审

**LLM 成本**: 每条候选改动 ~5K input + ~2K output tokens（读 scan-arkts.sh + 写 diff），用 Sonnet 一晚 100 次 ≈ $2-5。

## 3. 第二适配候选：`autosample` —— 范例自动新增

OctoDesk 经常需要"鸿蒙端做 X 怎么写"的最小骨架（picker、Noise XX 握手、SSE relay）。手工补很慢，但能 autoresearch 化：

```
fitness = (compile_pass: 0|1) + (scan_arkts_clean: 0|1) + (covers_target_api: 0|1)
```

- agent 写一个 `samples/templates/<topic>/Foo.ets`
- 跑 `hvigorw codeLinter` + `scan-arkts.sh` + 用户在 PROGRAM.md 列出 "必须出现的 API 调用集"
- 三项全过才 commit

这个 fitness 是离散布尔三项，比 F1 弱但也无歧义。**但风险**：agent 可能为通过测试写出"能编译但教错的"代码（例如：用 `try-catch` 包住但什么都不做）。需要在 PROGRAM.md 加"anti-pattern blacklist"，类似 `samples` 必须避免的写法。

## 4. 明确**不要**自动进化的部分

| 组件 | 原因 |
|------|-----|
| `tools/install.sh` / `doctor.sh` / `harmony-dev-cycle.sh` | 基础设施 / 影响所有下游；fitness 不可观测；agent 改坏的代价远高于人改快的收益 |
| `00-09/` 知识库 | LLM-as-judge "更清晰"是漂移信号；agent 会无止境优化措辞导致风格漂移 |
| `CLAUDE.md` / `AGENTS.md` / generate-ai-configs 输出 | 这些是 agent 的策略层；让 agent 改自己的策略是经典 unstable feedback loop |
| `upstream-docs/openharmony-docs/` | 这是 mirror，正确的"进化"是 `git pull` 而非 agent 推理 |

类比 autoresearch：他们也明确禁止 agent 改 `prepare.py`、改 `pyproject.toml` 依赖、改评测函数。这条边界 DevSpace 应该更宽松还是更严格？**应该更严格**——autoresearch 是单一研究者的实验仓，DevSpace 是被多个下游消费的"library"，破坏成本不对称。

## 5. 比 autoresearch 更省力的等价物：**反哺规约 + 半自动建议**

承认现实：DevSpace 现在并没有进化压力大到需要完整 autoresearch loop。目前更高 ROI 的做法是：

1. **codify 反哺约定**（已做 ✅）：OctoDesk CLAUDE.md 已写明"鸿蒙踩坑当场反哺 DevSpace"。这本身就是把人当 agent，把 OctoDesk 当外部信号源。
2. **半自动建议**: 写一个 `tools/suggest-rules.sh`：扫描 OctoDesk apps/harmonyos 最近 1 个月新增的 `// scan-ignore` + 没被 scan 抓到的 commit 模式，**生成候选规则草稿**让人审。比全自动 loop 简单 10 倍，95% 的实战价值。
3. **达到一定量再升级**: 当人工节奏开始跟不上下游实战速度（典型信号：候选规则积压 > 10 条 / 月，反哺延迟 > 2 周），再考虑实施 §2 的完整 loop。

autoresearch 的精髓不是"全自动"，是"**让每次迭代有客观可比的度量 + 让 keep/discard 决策机械化**"。即使不跑 LLM agent，让 DevSpace 形成"每条规则变更必须跑 corpus + 看 F1 是否升降"的习惯，就已经获得 80% 的价值。

## 6. 落地节奏（如果决定做）

| 阶段 | 工作量 | 收益 |
|------|-------|-----|
| **Phase 0**（已完成 2026-05-14） | OctoDesk 接 hook、反哺约定写进 CLAUDE.md、CSPRNG-001 第一条反哺规则、bridge-pitfalls.md 第一篇反哺文档 | 反哺循环跑通 |
| **Phase 1**（推荐 1-2 周内做） | 标注 50+50 corpus、写 `evaluate-lints.sh`、把现有 32 条规则跑一遍 baseline F1、放进 results.tsv | 每条规则的"基准好坏"有数字了 |
| **Phase 2**（可选，1 个月后） | 写 `PROGRAM.md`、跑一晚 autolint loop、人工审 keep 的改动 | 真正自动发现 1-2 条新规则 |
| **Phase 3**（远期）| OctoDesk PostToolUse 加 telemetry sink、聚合脚本、把"用户抑制率"作为额外 fitness 信号 | 数据驱动的规则进化 |

各阶段独立有价值，**绝不要跳到 Phase 2 之前先做 Phase 1**——没有 corpus 做基准，Phase 2 的 keep/discard 决策就是噪声。这一点 autoresearch 的 `prepare.py` + `evaluate_bpb` 必须先到位才允许跑 `train.py` 的设计也是同理。

## 7. 待讨论的开放问题

- corpus 怎么持续维护？autoresearch 用的是 climbmix-400b 这种公共大数据集；我们的 corpus 是手标的，规模上不去。可能要约定每个新规则进来必须配 ≥ 3 fixture（2 positive + 1 holdout）。
- F1 之外要不要考虑"业务侧实际收益"？例如某条规则只能抓到 1% 的违规但都是真 critical bug——只看 F1 会过滤掉这类。可能需要"严重度加权 F1"。
- agent 写出"为通过 corpus 而过度拟合"的规则怎么防？autoresearch 通过 holdout 缓解；我们要更严，可能需要"corpus 季度刷新 + 旧 fixture 退役"机制。
- 跑这个 loop 的物理位置？autoresearch 在 H100 上跑；我们的 evaluate 在 macOS 笔记本上 10 秒一轮——本机就行，不需要云。

---

## 附录 A：autoresearch 原文关键引用

- README: "you're not touching any of the Python files like you normally would as a researcher. Instead, you are programming the `program.md` Markdown files"
- program.md: "Single file to modify ... Fixed time budget ... Self-contained"
- program.md "NEVER STOP": "Once the experiment loop has begun (after the initial setup), do NOT pause to ask the human if you should continue"
- program.md "Simplicity criterion": "A small improvement that adds ugly complexity is not worth it. Conversely, removing something and getting equal or better results is a great outcome"

## 附录 B：与现有 DevSpace 工具的关系

- **`tools/test-suite.sh`**: 已经是雏形 evaluator，但跑的是 9 个 fixture 的二值 PASS/FAIL，不是 F1。autolint 的 evaluate-lints.sh 应该**补**而不是**替**。test-suite 验"规则没回归"；autolint 衡量"规则是否改得更好"。
- **`tools/hooks/test-fixtures/`**: 已有 9 个 `.ets` fixture（BadState / BadArkTS / BadSecurityKit 等），可以作为 corpus 的初始种子，扩展到 50+50。
- **`.claude/skills/harmonyos-review/references/checklist.md`** 36 条审查规则：是 scan-arkts 32 条之外的"人审" tier；autolint 不动它，但人审命中的真问题应该反向追问"为什么 scan-arkts 没抓"——作为候选规则的灵感源。
