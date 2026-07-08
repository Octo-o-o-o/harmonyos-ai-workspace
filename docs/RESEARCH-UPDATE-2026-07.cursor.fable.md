# 2026-07 更新调研与实施方案（cursor.fable）

> 基线：commit `a208828`（2026-07-08）· 版本 v0.4.5 · 调研日期 2026-07-09
> 调研方法：互联网检索（华为官方 release notes / npm / OHPM registry / GitHub 同类项目）+ OHPM openapi 实测核验 + 本仓库全量盘点（explore agent 逐文件 rg）
> 本文档 = 调研结果 + 借鉴评估 + 错误清点 + 更新方案 + 方案自 review。实施后的对账见 CHANGELOG。

---

## TL;DR

1. **版本叙述全面过时（P0）**：仓库仍写"API 22 现行稳定 / API 23 Developer Beta"。现实：**6.1.0(23) 已于 2026-04-20 Release、6.1.1(24) 已于 2026-05-26 Release、HarmonyOS 7(API 26) Developer Beta1 已于 2026-06-12 发布（没有 API 25）**。全仓约 80+ 处引用点需更新（见 §3.1）。
2. **发现 2 个真 bug（P0）**：① OHPM 黑名单把真实存在的 `@ohos/axios`（OHPM v2.2.12，20 万+ 下载，TPC 官方移植）判为"AI 虚构包"——High 级误杀；② `check-ohpm-deps.sh` 用 `ohpm view`，而 ohpm 6.x 已改为 `ohpm info`，第 3 层在线校验整层失效。
3. **测试/质量评估是全仓最大空白（P1，用户点名）**：8 个 skill、26 个模板、12 个 dev-cycle 子命令中**没有任何一个**覆盖 hypium / UiTest / `aa test` / AGC 云测。补 1 个 skill + 1 个模板 + dev-cycle `test` 子命令 + 最佳实践扩写。
4. **官方 AI 工具链出现（P1）**：HDC 2026（6-12）发布 DevEco Code（OpenCode 改的鸿蒙 AI agent）与 DevEco CLI（`@deveco/deveco-cli`，封装 ohpm/hvigor/hdc/模拟器/hilog + skills + MCP）。与本项目是**互补不是替代**（官方管构建原子能力，本项目管规则/扫描/实战反哺），需文档化集成姿势。
5. 同类项目借鉴评估结论：**A×2 / B×3 / C×4**，第一刀 = 版本保鲜机制 + 测试 skill（见 §2）。

---

## 一、外部现实变化（逐条带来源）

### 1.1 系统与 API 版本线

| 事件 | 日期 | 关键事实 |
| --- | --- | --- |
| HarmonyOS 6.1.0 (API 23) Release | 2026-04-20 | 与 DevEco Studio 6.1.0 Release（6.1.0.830）+ SDK 6.1.0.105 同日 Release；华为 Pura 系列发布会宣布 HarmonyOS 6 设备数破 5500 万；Release 配套 ROM 自 2026-03-20 起分发 |
| HarmonyOS 6.1.1 (API 24) Release | 2026-05-26 | API 24 转正（脱离 Beta）；DevEco Studio 6.1.1 Release（6.1.1.280）+ SDK 6.1.1.125；Hot Reload 支持 C++/资源、AppFreeze 日志解析增强、ComMemory 模板 |
| HarmonyOS 7 (API 26) Developer Beta1 | 2026-06-12（HDC 2026） | **跳过 API 25**；公开招募 6/12–7/5，限 Mate 80 Pro / Mate X7 / Pura X 等 7 机型；主打 Agent 架构、鸿蒙智能体框架 2.0、空间计算；HarmonyOS 6 设备数破 6600 万 |
| DevEco Studio 26.0.0 Beta1 | 2026-06 | **版本号切换为年份制**（6.1.1 → 26.0.0）；内置 Node.js 18 → 24（hvigor/ohpm 自定义插件需适配）；支持 API 26 工程；集成 HarmonyOS Agent 问答/MCP Market |
| ArkTS-Sta（静态模式） | 演进中 | `use static` 文件级导语 + ANI（替代 NAPI）；官方文档标注"持续演进中"，**未到生产推荐阶段** |

API 编号 ↔ 系统版本对照（更新后单一权威表）：
`6.0.0=20（仅开发者版）· 6.0.1=21 · 6.0.2=22 · 6.1.0=23 · 6.1.1=24 ·（无 25）· 7.0 Beta=26`

**targetSDK 建议的决策**：延续本仓库既有保守策略（上一轮选 21 = HarmonyOS 6 首发线而非最新 22）。本轮推荐 **target 23（6.1.0，Release 近 3 个月、消费推送覆盖广）/ min 12**；需要 API 24 新能力才上 24；API 26 仅尝鲜。`current_consumer_stable` 更新为 24，注释注明"API/SDK/IDE 已全 Release，ROM 推送节奏以华为升级名单为准"（诚实表述，不夸大 24 的装机量）。

### 1.2 官方 AI 工具链（HDC 2026 新增，与本项目定位直接相关）

- **DevEco Code**：基于 OpenCode 扩展的鸿蒙 AI agent（TUI），内置 GLM-5.1 免费模型、5 个鸿蒙 Skill、build_project / start_app / hdc_log / verify_ui / check_ets_files / arkts_knowledge_search 等工具，支持第三方模型。面向"想开箱即用"的开发者。
- **DevEco CLI**（`@deveco/deveco-cli`，Apache 2.0，开源在 gitcode openharmony-sig/codegenie_tools）：把 DevEco Studio 工具链（ohpm/hvigor/hdc/emulator/hilog）封装为单一 CLI + 项目脚手架 + 本地文档检索 + deveco-mcp（ArkTS/C++ 语法检查）+ `init --agent` 一键装 skill 到 Claude Code / Cursor / OpenCode 等。要求 DevEco Studio ≥ 6.1.0、macOS 或 Windows。
- **与本项目关系判定**：DevEco CLI 覆盖了 `harmony-dev-cycle.sh` 的一部分（build/run/log/模拟器管理，且官方能启动模拟器——本脚本做不到），但**不覆盖**本项目核心价值：60+ 编号规则扫描钩子、OHPM 伪包校验、AGC 拒因清单、实战反哺 case studies、多工具规则 fan-out、install manifest。结论：**互补**。策略 = 文档化"两者一起用"的姿势，不重写自家脚本去包 devecocli（越界且增加依赖）。

### 1.3 OHPM 生态事实核验（本会话实测，curl OHPM openapi + ohpm CLI）

| 包名 | 实测结果 | 对本仓库的影响 |
| --- | --- | --- |
| `@ohos/axios` | **存在**：v2.2.12，20 万+ 下载，TPC 官方（gitcode CPF-ApplicationTPC/ohos_axios），compatibleSdkVersion 12 | **黑名单误判（P0）**：内联黑名单第 28 行 + data 文件 + CLAUDE.md/AGENTS.md/README 多处叙述"axios 不存在"全部要改 |
| `@ohos/socketio` | 存在：v2.1.4，TPC 官方 | 黑名单 `@ohos/socket.io-client` 条目保留但理由改为"正确包名是 @ohos/socketio" |
| `@ohos/crypto-js` | 存在：v2.0.5 | 加白名单 |
| `dayjs`（无前缀） | 存在：v1.11.13，packageType=WHITELIST（OHPM 白名单化的纯 JS npm 包） | `@ohos/dayjs` 确实不存在，黑名单保留，理由改为"OHPM 直接用 dayjs（纯 JS 白名单包）" |
| `lodash`（无前缀） | 存在：v4.17.21，WHITELIST | `@ohos/lodash` 黑名单保留，理由更新 |
| `@ohos/dayjs` `@ohos/uuid` `@ohos/lodash` `@ohos/moment` `uuid` `moment` | **均不存在**（openapi 返回 `"body":"success"` = 查无此包，与故意乱造的包名行为一致） | 黑名单这些条目正确，保留 |
| ohpm CLI 行为 | ohpm 6.1.2.268 **没有 `view` 子命令**（改为 `info`）；且 registry 端点 502 时 ohpm 会误报 `NOTFOUND ... from all the registries` | `check-ohpm-deps.sh` 第 3 层失效（P0）；网络错误分类的正则顺序（先 network 后 not-found）碰巧防住了 502 误判，保留该顺序 |
| OHPM web openapi | `https://ohpm.openharmony.cn/ohpmweb/registry/oh-package/openapi/v1/detail/<urlencoded-name>`：存在返回包详情 JSON，不存在返回 `{"code":200,"body":"success"}`；实测比 ohpm CLI 的 registry 端点稳定 | 作为新的第 3 层在线校验（curl），ohpm CLI 降为 fallback；非公开接口，失败时按网络类降级不阻断 |

**教科书级教训**（写进 CHANGELOG 与黑名单头注释）：黑名单条目当初凭"npm 生态包不存在于鸿蒙"的推断写入，未逐条对 registry 核验。TPC（OpenHarmony 三方库中心）持续在移植 npm 知名库，"不存在"是时变事实，**黑名单必须只收录核验过的当前事实 + 定期重核**。

### 1.4 测试与质量评估体系（官方现状）

- **Test Kit**（`@kit.TestKit`，本地镜像 `application-test/` 有全套指南）：
  - **JsUnit（单元测试框架）**：`@ohos/hypium`（ohpm 独立发版，DevEco 模板自带 devDependency）。describe/it/expect + Mock（`@ohos/hamock`）+ 数据驱动 + 压力/随机/遇错即停。
  - **UiTest（UI 测试框架）**：`Driver` / `ON` / `Component`，控件查找、点击滑动输入、窗口操作、截图、`waitForComponent`。脚本跑在单元框架之上，位于 `src/ohosTest/`。
  - **PerfTest（白盒性能，API 20+）**：代码段耗时 / CPU / 内存采集。
  - 命令行执行：`hdc shell aa test -b <bundle> -m <module> -s unittest OpenHarmonyTestRunner`（-s class/-s timeout/-s breakOnError 等过滤参数）；ohosTest HAP 需要签名。
  - CLI 工具：SmartPerf（FPS/CPU/GPU/RAM/功耗）、wukong（随机事件注入稳定性测试）。
- **AGC 云测（上架自检）**：AppGallery Connect → 软件包管理 → "启动自检"，云端自动化检测兼容性/稳定性/性能/功耗/UX/隐私，提审前定位拒因。2026 审核重点：隐私合规 TOP8（同意前不得取权限、隐私标签一致性）、应用信息 TOP9、2026-01-07 起截图新规。
- **本仓库现状**（explore agent 盘点）：`05-best-practices/README.md` §6 仅 17 行提纲；无测试 skill、无测试模板、`harmony-dev-cycle.sh` 12 个子命令无 test；review 模板只有两个字段提及。**这是全仓库相对官方能力面的最大空白**，且与本项目定位（让 AI 写出的 app 质量更好）直接相关。

---

## 二、同类项目借鉴评估（borrow-assess）

对方项目均为 2026 年活跃的"鸿蒙 AI 编码知识包"。license 核验：三者均 MIT，无复制限制；本评估只借设计不复制文本。

### 能力登记表与裁决

| # | 能力/设计 | 出处 | 本仓库现状（实证） | 裁决 | 理由 |
| --- | --- | --- | --- | --- | --- |
| 1 | **版本保鲜节奏**：README 顶部声明"生产基线覆盖 API 24（2026-05-26），跟踪 API 26 Beta1（2026-06-12）"，跟随官方版本 1-2 周内更新 | DengShiyingA/harmonyos-ai-skill（150★） | 本仓 `last_verified_docs_snapshot: 2026-05-07`，版本叙述停在 API 22/23 Beta，落后两个 Release | **A 直接借** | 这正是本次更新的主体；借"保鲜承诺+基线声明"的做法，README 版本契约加 API 对照表 |
| 2 | **测试框架知识**（arkxtest：JsUnit + UiTest 章节 + 用例示例） | DengShiyingA（"工程质量"章）、Brabrix skill hub 的 arkts-testing 规则 | 本仓**空白**（§1.4） | **A 直接借** | 用户点名 + 官方文档齐全，做成本仓风格：skill + 可跑模板 + dev-cycle 子命令，比对方的纯知识文本更进一步 |
| 3 | 60+ Kit 逐个知识条目（Camera/Audio/Map/Push/Form…每 Kit 带 import + 示例） | DengShiyingA（4440 行单文件） | 本仓 `03-platform-apis/` 只有分类索引，靠 upstream-docs 镜像检索 | **C 不借** | 半衰期短（API 12→24 多次变化正是本仓反复强调的坑）；4440 行 always-in-context 与本仓"按需触发 skill"架构冲突；镜像检索已覆盖该需求 |
| 4 | 单文件源 → 11+ 工具 fan-out（含 Gemini CLI / Windsurf / Cline / Continue） | DengShiyingA | 本仓 fan-out 覆盖 Claude/Codex/Cursor/Copilot 4 家（`generate-ai-configs.sh`） | **C 不借**（本轮） | 本仓用户面（安装器形态）以 4 家为主；加 7 个低频目标的维护成本 > 收益；AGENTS.md 标准本身已覆盖多数新工具 |
| 5 | `npx skills add` 标准安装形态 | FadingLight9291117/arkts_skills（7★） | 本仓有自己的 `install.sh`（manifest+sha256）+ npm CLI | **C 不借** | 已有更完善的安装机制；双轨会引入一致性负担 |
| 6 | build-deploy skill 独立拆分（构建/部署与语言规则分离） | FadingLight9291117 | 本仓已有 `build-debug` skill（等价物） | **C 不借** | 已有，无缺口 |
| 7 | **官方 DevEco CLI 集成**：`devecocli init --agent claude-code` 一键接入 + deveco-mcp 语法检查 | 华为官方（HDC 2026） | 本仓 `.mcp.json` 只接 mcp-harmonyos；`docs/MCP-INTEGRATION.md` 未提 deveco-mcp；README/build-debug 无 DevEco CLI 叙述 | **B 改造借** | 不把 devecocli 变成依赖（Linux 不支持、要求 DevEco ≥ 6.1.0），但在 build-debug skill + 04 文档 + MCP-INTEGRATION 补"何时用官方 CLI、与本仓工具如何分工"的指引 |
| 8 | DevEco Code 的 verify_ui（多模态模型驱动 UI 意图验证 agent） | 华为官方 | 本仓无 | **C 不借**（记录于此） | 依赖华为闭源服务 + 多模态模型；本仓是规则/知识包不是 agent runtime；在测试 skill 里提及其存在即可 |
| 9 | 版本对照/迁移章节（"6.0 升 6.1 改动点"类内容：modelVersion、targetSdkVersion 写法） | 慕课/waylau 文章 + DengShiyingA | 本仓 build-debug 有 9568297 的 API 编号对照表（20-24） | **B 改造借** | 对照表加 26 行 + "无 25" 注记 + `"targetSdkVersion": "6.1.0(23)"` 字符串格式示例（AI 常写错这个格式） |

**承重现状盘点**（防"把已做当没做"）：本仓已有且对方没有的——PostToolUse 强校验钩子（60+ 规则、装饰器上下文、inline-suppress、0 假阳实测）、OHPM 四类校验、AGC-RJ 拒因 ID 体系、真工程反哺 case studies ×2、install manifest+sha256、monorepo wrapper、doctor 体检、scaffold 脚手架、dev-cycle 调试闭环。**这些是护城河，本次更新只加强（修 ohpm bug、补测试），不动架构。**

**第一刀**：#1 版本保鲜 + #2 测试补全 +（顺带）P0 黑名单纠错——三者合成本次 v0.5.0。

---

## 三、本项目错误 / 疏漏 / 不足清点

### 3.1 错误（事实性，必须改）

| # | 问题 | 证据 | 影响 |
| --- | --- | --- | --- |
| E1 | 版本叙述全面过时：README 版本契约、CLAUDE.md §1、AGENTS.md §1、llms.txt、manifest.json、16 个 SKILL.md frontmatter（`verified_against: harmonyos-6.0.2-api22`）、00-getting-started ×4、docs/SETUP ×1、fan-out 生成物 ×6、scaffold/setup/verify 脚本默认值、13 个模板 verified_against | explore agent 全量清单（~80 处，文件+行号已存档在盘点报告） | AI 读到"API 23 是 Beta 别用于生产"会给出错误建议；scaffold 默认 target 过旧 |
| E2 | `@ohos/axios` 黑名单误判（同时 README 痛点表格、CLAUDE.md §11.2、AGENTS.md §9 都拿 axios 当"虚构包"例子） | §1.3 实测：OHPM v2.2.12 真实存在 | **High 级误杀**：用户合法依赖被钩子 exit 2 阻断；对外可信度伤害 |
| E3 | `check-ohpm-deps.sh` 用 `ohpm view`，ohpm 6.x 只有 `info` | 本机 ohpm 6.1.2.268 实测 `unknown command 'view'` | 第 3 层在线校验失效，全部降级为 UNKNOWN 噪音 |
| E4 | "axios / lodash / moment 等 npm 名包不存在于鸿蒙生态"的一刀切叙述（多处） | §1.3：TPC 移植版 + OHPM WHITELIST 纯 JS 包机制存在 | 误导 AI 拒绝合法方案；应改为"npm 包不能直接 import，但 OHPM 有 TPC 移植版（@ohos/axios）与白名单纯 JS 包（dayjs/lodash），用前必核验" |

### 3.2 疏漏（能力空白）

| # | 空白 | 补什么 |
| --- | --- | --- |
| G1 | 测试/质量评估全空白（§1.4） | 新 skill `testing-quality` + 模板 `samples/templates/hypium-uitest/` + `harmony-dev-cycle.sh test` 子命令 + `05-best-practices` §6 扩写 + review checklist 加 TEST-001/002 |
| G2 | DevEco CLI / DevEco Code 官方工具不知情 | build-debug skill + `04-build-debug-tools/README` + `docs/MCP-INTEGRATION.md` 各加一节；README 相关链接 |
| G3 | AGC 云测（上架自检）未提及 | signing-publish skill + 07-publishing checklist 加"提审前跑云测自检"建议（一段，不新增 ID 体系） |
| G4 | API 编号对照表止步 24 | build-debug 对照表补 26 + "无 25"注记 |
| G5 | ArkTS-Sta（`use static`）不知情 | CLAUDE.md/AGENTS.md 背景一句 + arkts-rules skill 一段"存在性知情"（明确：演进中、生产不用、本仓规则针对动态 ArkTS） |
| G6 | 版本契约 `arkts: ">= 1.2.0"` 语义混乱（ArkTS-Sta 出现后 1.2 有歧义） | 契约里删 arkts 版本行，改为文字说明 |

### 3.3 不足（质量改进，本轮做低成本项）

- `state-management` skill：PersistenceV2 globalConnect 集合持久化（API 23 新能力）值得一句话补充——**做**（一行成本）。
- `hvigorw test` 在 09-quick-reference 出现但无解释，且本地单元测试（`src/test/`）CLI 跑法官方文档未记载——测试 skill 里诚实写"Local 单元测试建议 DevEco GUI 跑；CLI 权威路径是 ohosTest 上设备 `aa test`"，**不发明** `test@ut` 之类未核验命令。
- `.claude/skills` 与 `.agents/skills` 镜像一致性良好（盘点确认仅预期差异），本轮同步双改即可。

---

## 四、更新方案（分级）

### P0 事实修正
1. **版本叙述统一更新**（真源→fan-out 顺序）：
   - 真源：README 版本契约 yaml + 关键事实节 → CLAUDE.md → AGENTS.md → llms.txt → manifest.json → `generate-ai-configs.sh` 内嵌硬约束段（行 98）
   - 重跑 `bash tools/generate-ai-configs.sh` 再生成 `.cursor/rules/*.mdc` + `.github/*`
   - Skills frontmatter：16 处 `verified_against: harmonyos-6.1.1-api24`，注明本轮为 **docs-checked**（对照官方 6.1.x release notes 核验规则仍成立，未逐条真机重跑——诚实标注）
   - 00-getting-started ×4、docs/SETUP-FROM-SCRATCH、docs/USAGE-GUIDE、05-best-practices/bridge §16 主线叙述、案例文档措辞
   - 脚本默认值：`scaffold-deveco-project.sh --api-target` 默认 22→23（SDK_VERSION 已是 6.1.1(24) 保持）、`setup-from-scratch.sh`/`verify-environment.sh` SDK 勾选建议 21+22→23+24
   - 模板 13 处 `verified_against` → api24 docs-checked
   - 新叙述模板：`当前最新 Release：API 24（6.1.1，2026-05-26）· 消费推送主力：API 23（6.1.0，2026-04-20 起）· 开发者预览：API 26（HarmonyOS 7 Beta1，2026-06-12，无 API 25）· 新项目推荐 target 23 / min 12`
2. **OHPM 纠错**：
   - 黑名单（内联 + data 文件）：删 `@ohos/axios` 条目；`@ohos/dayjs`/`@ohos/lodash`/`@ohos/socket.io-client` 理由改为指向真实替代（dayjs 白名单包 / lodash 白名单包 / @ohos/socketio）
   - 白名单（内联 + data 文件）：加 `@ohos/axios`、`@ohos/socketio`、`@ohos/crypto-js`、`dayjs`、`lodash`
   - 黑名单文件头加维护纪律注释："只收录核验过的当前事实；每次 release 前重核 registry"
   - 文档叙述（README 痛点表、CLAUDE.md §11.2、AGENTS.md §9、multimodal-llm skill 若有）改为三层表述：不能直接 import npm → OHPM 有 TPC 移植版与白名单纯 JS 包 → 用前必核验
3. **check-ohpm-deps.sh 修复**：
   - 在线校验层重构：第 3 层改为 curl OHPM openapi（15s timeout；`"body":"success"`→FAKE、包详情→OK、curl 失败→网络类降级）；第 3.5 层 ohpm CLI fallback（探测 `info`/`view` 哪个可用；`unknown command` → 视为 CLI 不可用跳过）
   - `test-suite.sh` 加断言：`@ohos/axios` 不再命中 FAKE；黑名单条目仍命中
4. **CHANGELOG**：Unreleased 收口为 v0.5.0，附本轮全部变更 + 误判致歉说明；`package.json` + `manifest.json` → 0.5.0

### P1 测试/质量评估补全（用户点名的主体新增）
5. **新 skill：`.claude/skills/testing-quality/SKILL.md`**（+ `.agents/skills/` 镜像 + manifest 注册 + CLAUDE.md/AGENTS.md 触发索引行）：
   - 激活条件：写测试/hypium/UiTest/aa test/云测/上架自检/性能摸底关键词
   - 内容（目标 ≤ 350 行，本仓 skill 风格：铁律 + 速查 + 反模式）：
     a. 测试金字塔在鸿蒙的映射：`src/test/`（Local 纯逻辑）vs `src/ohosTest/`（设备上 instrument）
     b. hypium 最小用例 + 断言族 + hamock + 数据驱动一表
     c. UiTest：`@kit.TestKit` import、Driver/ON 速查表、`waitForComponent` 优于 `delayMs`、findComponent 用 id/text 不用坐标
     d. 命令行：`hdc shell aa test ... -s unittest OpenHarmonyTestRunner` 参数族 + ohosTest HAP 签名前置 + 结果解读
     e. 常见坑：ohosTest 未签名、异步用例忘 await/done、V2 状态类测试要点、测试与生产 bundle 隔离
     f. 质量评估工位：DevEco Profiler（已有 build-debug 引用）、SmartPerf、wukong、AGC 云测自检——各一段"什么时候用哪个"
     g. AI 协作范式：让 AI 先写纯逻辑单测（低成本高信度）、UI 测试只覆盖关键路径
   - **不进默认 fan-out**（与 web-bridge 同级的按需专项，避免上下文膨胀），但 CLAUDE.md §2.5 / AGENTS.md §0 索引表加行
6. **新模板：`samples/templates/hypium-uitest/`**：
   - `CalcLogic.test.ets`（Local 纯逻辑单测，describe/it/expect/beforeAll）+ `LoginPage.uitest.ets`（ohosTest：Driver 查找+点击+断言）+ README（目录放置、DevEco 跑法、aa test CLI 跑法、CI 片段、签名注意）
   - 过 `scan-arkts.sh` 自检 exit 0；README 标注 verified_against api24 docs-checked
7. **`harmony-dev-cycle.sh` 加 `test` 子命令**：
   - 路径 = 官方记载的设备路线：`hvigorw assembleHap -p module=entry@ohosTest`（构建测试 HAP）→ 安装主 HAP + 测试 HAP → `hdc shell aa test -b <bundle> -m entry_test -s unittest OpenHarmonyTestRunner`（模块名自动从 module.json5 读，支持 --module 覆盖）→ 输出透传 + 摘要
   - usage 注释同步；README/04 文档提及
8. **`05-best-practices/README.md` §6 扩写**（17 行 → 约 60 行）：指向 skill/模板/dev-cycle test/云测；`04-build-debug-tools/README.md` 加 aa test 一段
9. **harmonyos-review checklist**：加 `TEST-001`（核心业务逻辑无任何 hypium 单测——Medium 提示级）`TEST-002`（ohosTest 依赖生产环境端点/真实账号——High）两条；report-template 测试字段引用它们

### P1 生态知情更新
10. DevEco CLI/Code：`build-debug` skill 加"官方 CLI 分工"一节（≤ 20 行）；`04-build-debug-tools/README.md` 加安装与 init 示例；`docs/MCP-INTEGRATION.md` 加 deveco-mcp 段；README 相关链接 + 内置内容表一句定位说明
11. ArkTS-Sta 知情：CLAUDE.md 背景行 + arkts-rules skill 尾部一段（本仓规则针对动态 ArkTS；`use static` 演进中勿用于生产；看到 `use static` 文件不要套用本仓状态管理规则）
12. state-management skill：PersistenceV2 globalConnect 集合持久化一句（API 23+）
13. signing-publish skill + 07-publishing：AGC 云测自检段 + 2026-01-07 截图新规一句

### P2 收尾
14. 重跑 `generate-ai-configs.sh` + `test-suite.sh` 全量回归 + `doctor.sh`
15. `docs/REVIEW-NEXT-STEPS-2026-05.md` 中已完成项标记
16. git：单支线 commit 序列（P0 事实修正 / OHPM 修复 / 测试补全 / 生态更新 / 发版收口）→ tag v0.5.0 → push origin main + tag

### 明确不做（防过度设计）
- ❌ 60+ Kit 百科（半衰期短、镜像已覆盖检索）
- ❌ fan-out 扩到 11+ 工具（维护成本>收益）
- ❌ 重写 dev-cycle 去包 devecocli（引入依赖与平台限制）
- ❌ PerfTest/SmartPerf/wukong 模板（真机依赖重、低频；skill 指引即可）
- ❌ ArkTS-Sta 教程（官方标注演进中）
- ❌ npm publish（未被要求；发版工序涉及 OTP）
- ❌ upstream-docs 镜像重拉（本地已含 6.1 文档；2.7GB 网络成本大且不入库）
- ❌ 新增 scan-arkts 规则（本轮调研未发现可靠的新 grep 素材，不为凑数硬加）

---

## 五、方案自 review

**合理性**：P0 全部是实证错误（版本过时 80+ 处、黑名单误杀、CLI 命令失效），修复优先级无争议。P1 测试补全是用户点名 + 盘点确认的最大空白，形态（skill+模板+子命令）与本仓既有架构完全同构，不引入新概念。

**正确性核查**：
- 版本事实三源交叉（华为官方 release notes 页 / IT之家等媒体 / 官方文档镜像 GitHub 副本），日期一致 ✅
- OHPM 包存在性用 registry openapi 直接核验而非二手文章 ✅（文章说 "@ohos/dayjs 存在" 就是错的，实测不存在——证明必须一手核验）
- `aa test` 命令族逐字来自本地官方镜像 unittest-guidelines.md ✅；不写未核验的 `hvigorw test@ut`（仅社区文章出现，官方指南未记载）✅
- targetSDK 建议延续项目既有保守逻辑（首选已广泛推送的版本）✅

**可行性**：全部为文档/脚本/skill 层改动，无外部依赖；test 子命令依赖的 hvigorw/hdc 调用模式与现有 build/install 子命令同构；curl openapi 已实测可用且有降级路径。风险点：openapi 属非公开接口可能变动——已设计失败降级不阻断，可接受。

**完整性**：对照用户要求逐项——官方文档/版本变化 ✅（§1）；同类项目借鉴 ✅（§2，A×2/B×3/C×4）；不足/错误/疏漏 ✅（§3，E×4/G×6）；方便开发者+app 质量 ✅（测试/云测/审核合规/官方工具集成）；测试和评估 app ✅（§4.5-9）。盘点报告的 80+ 处版本引用已按文件分组进实施清单。

**无过度设计检查**：逐项过"是否为了做而做"——①testing skill 不进默认 fan-out（按需触发）✅；②review 只加 2 条 TEST 规则而非一套新 ID 体系 ✅；③DevEco CLI 只做文档集成不做代码依赖 ✅；④ArkTS-Sta 只做知情不做教程 ✅；⑤不硬加 scan 规则凑数 ✅；⑥模板只做 hypium+UiTest 一个（不做 PerfTest 三件套）✅。

**残余风险**：verified_against 升到 api24 但为 docs-checked 而非真机 re-run——已决定在 frontmatter 注释与 CHANGELOG 明示验证方式，诚实不夸大。

**Review 后补充的实施细节**（首轮方案遗漏，二轮核对源码后补入）：
- `tools/install.sh` 行 281/294 两处硬编码 skill 清单需加 `testing-quality`（否则下游安装拿不到新 skill）；`package.json` files 已含 `.claude/skills/` 整目录，无需改
- `README.md` 与 `docs/USER-GUIDE.md` 中 "`ohpm view`" 文案随脚本修复改为 "`ohpm info`/registry openapi"
- `tools/scaffold-deveco-project.sh` 存在内部不一致：`SDK_VERSION` 默认已是 `6.1.1(24)` 而 `--api-target` 默认 22——本轮统一为 target 23 + SDK 对应版本串，实施时读脚本核对生成逻辑

> 结论：方案通过自 review，按 §4 顺序实施。实施后跑全量回归（test-suite 34+ 项）+ doctor + subagent review，再推送。

---

## 六、实施对账（2026-07-09 实施完成后回填）

- §4 P0/P1/P2 全部落地，明细见 [`CHANGELOG.md` v0.5.0](../CHANGELOG.md)；"明确不做"清单未突破。
- 验证证据：`tools/test-suite.sh` **40 passed, 0 failed**（含 2 条新增的黑名单误杀回归断言 + 新模板自动纳入 sample 扫描）；`generate-ai-configs.sh --check` 通过；`doctor.sh` 9 skills 双侧识别（唯一 FAIL 是"当前目录不是鸿蒙 app 工程"，对 DevSpace 本体属预期）。
- 实施中在方案外新发现并顺手修正：`scaffold-deveco-project.sh` 的 `--api-target 22` 与 `SDK_VERSION 6.1.1(24)` 内部矛盾（会生成 compatible > target 的工程配置）；`04-build-debug-tools` oh-package 示例 `modelVersion 5.0.0` 过旧；`bin/cli.js` 版本提示串。
- 改动规模：80 文件 +560/-210，另新增 5 组文件（testing-quality skill ×2 镜像、hypium-uitest 模板、good-oh-package fixture、本文档）。
