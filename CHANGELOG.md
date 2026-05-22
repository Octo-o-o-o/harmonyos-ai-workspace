# Changelog

遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) + [SemVer](https://semver.org/lang/zh-CN/)。版本节奏跟随 HarmonyOS 大版本。

> **Git tag 历史**：本仓库 git tag 从 [v0.2.0](https://github.com/Octo-o-o-o/harmonyos-ai-workspace/releases/tag/v0.2.0) 起（GitHub initial commit `83a71b2` 即名为 "Initial release v0.2.0"）。**v0.1.0 是 v0.2.0 之前的本地阶段性里程碑**（仓库雏形：10 主题目录 + 4 SKILL + LICENSE 等），无独立 git snapshot——保留 changelog 段是为了完整记录构建路径，但**没有对应 GitHub release**。

## [Unreleased]

### Added

- Codex 项目级分发补齐：`.agents/skills/` 纳入仓库 / npm files / `tools/install.sh --targets=codex`，让 Codex CLI / Desktop 能自动发现 8 个 HarmonyOS Skills。
- Codex MCP 配置补齐：新增 `.codex/config.toml` 发布链路，`doctor` 会检查 `mcp-harmonyos` 是否对 Codex 可见。

### Fixed

- 修正 Codex 文档与安装提示：`AGENTS.md`、`README.md`、`docs/USER-GUIDE.md`、`llms.txt` 同步说明 `.agents/skills` 与 `.codex/config.toml`。
- 修正 `bin/cli.js` 的 `doctor` 缺失提示版本号（`v0.4.5+`）。
- 修正 `tools/doctor.sh --json` 在 WARN / FAIL 场景混入人类可读行、导致 JSON 无法解析的问题，并补回归断言。
- 修正一处 `.agents/skills/multimodal-llm` 触发文案，把误写的 `Codex Vision` 还原为 `Claude Vision`。

## [0.4.5] - 2026-05-22

**主题：四轮反哺合并**——本版承载三个下游 app（paseo-harmony Phase A/B、OctoDesk N2/N3/N4、LCC M13）+ DevSpace 自身 2026-05-14 起累积的实战教训沉淀。共新增 9 条 scan-arkts 规则 / 8 个 runtime-pitfalls 章节 / 4 个 bridge-integration-pitfalls §8-§11 章节 / 4 个进阶 samples/templates + monorepo-consumer 接入样例 / 1 处 build-debug 错误码 / 1 处 case-study M13 + 1 个完整 case-study `android-parity-migration.md`。

### 2026-05-22 · paseo-harmony Phase A/B 反哺（NavPathStack / emoji / Button padding / build() root / timeline / per-host store / workspaceId）

来源：基于一个真实鸿蒙端 client 项目（paseo-harmony，对齐 Expo/RN 上游）的 Phase A/B 实战反馈整理。完整 case study 见 [`docs/case-studies/android-parity-migration.md`](docs/case-studies/android-parity-migration.md)。

**新增规则**（详见 [`.claude/skills/arkts-rules/references/spec-quick-ref.md`](.claude/skills/arkts-rules/references/spec-quick-ref.md)）：

- `NAV-001` NavPathStack 空 stack 白屏（Splash → replacePathByName 后目标页是栈底时必踩）
- `UI-001` ArkUI emoji / Unicode 高码位字符鸿蒙系统字体不显示（fallback ASCII / 中文单字 / SymbolGlyph）
- `UI-002` Button 默认 horizontal padding 吃掉 width，多字符文本被 ellipsis 截断（小按钮用 Text + onClick）
- `UI-003` `build()` 必须单 root container（多分支 wrap Column）
- `STATE-010` Per-host store 必须按 `${serverId}:${...}` 联合 key 隔离（多 host 串扰）
- `STATE-011` Timeline 写入跳过 reducer 导致 timestamp 等元数据丢失（必走 `applyFetchedEntries`）
- `TYPES-005` `Record<string, Object>` 字面量 → `JSON.parse('{}') as Record<...>` hack
- `TYPES-006` ArkTS union `T | null` 在 if 内可能被推成 `never` — 显式 `as` cast
- `TYPES-007` daemon "应该是 uuid" 的字段在某些 workspace 类型可能填 path → 必须 cwd / displayName fallback

**runtime-pitfalls/SKILL.md** 新增 § 十～十六：

- 十、NavPathStack.pop() 到空 stack → 白屏
- 十一、ArkUI emoji / Unicode 高码位字符渲染不可靠
- 十二、ArkUI Button width 限定 + 默认 padding 截断多字符
- 十三、ArkUI build() 必须单 root container
- 十四、Workspace timeline timestamp 丢失 — 绕过 reducer
- 十五、Per-host store 必须按 serverId 隔离
- 十六、daemon `agent.workspaceId` 不可靠 — cwd fallback 匹配

**新增 case study** `docs/case-studies/android-parity-migration.md`：

14 个阶段的真实修复笔记，覆盖：Splash → 主入口路由白屏、emoji 渲染陷阱、Button padding 截断、历史 session 加载、消息 timestamp 注入、per-host store 隔离、MessageBubble 类型分发、协议 envelope 双层 vs 顶级、Codex review 流程、列表页 vs 详情页预拉策略、ArkTS 类型推断 union null never bug、真机 hdc + screenshot 工作流。

每章 **症状 → 根因 → 修复 → 一句话教训** 结构，含可复用的 helper 代码与 review prompt 框架。

### 2026-05-22 · OctoDesk N4 反哺（HMS ScanKit + token 写入原子性 + pasteboard + App-Linking）

来自 OctoDesk Mobile Companion `apps/harmonyos/**` 自 2026-05-15 起的 ~30 个 commit 实战教训（desktop remote QR 配对、外部 OAuth、Auth refresh 路径、剪贴板 pair link 自动提示）：

- **`KIT-003` scan-arkts 新规则（Medium）**：`@kit.ScanKit` 直接 dynamic import 在 HarmonyOS NEXT 6.x 真机不稳。
  - 触发条件：`import('@kit.ScanKit')` 或 `from '@kit.ScanKit'`
  - 来源：OctoDesk `DesktopRemoteQrScanner.ets` 真机实测 `scanKit.scanBarcode` / `scanKit.scanCore` 解析为 `undefined`（默认 export 形态在某些镜像下不对），模拟器不一致
  - 标准做法：dual-import `@hms.core.scan.scanBarcode` + `@hms.core.scan.scanCore`，显式取 `.default`
  - inline-suppress 支持：`// scan-ignore: KIT-003`
- **`KIT-004` scan-arkts 新规则（High）**：HMS ScanKit `ScanType.QRCODE` 在 HarmonyOS 6.x 已改名为 `QR_CODE`。
  - 触发条件：`\bScanType\.QRCODE\b`（旧名是 word boundary 匹配，新名 `QR_CODE` 含 `_` 不会误命中）
  - 来源：OctoDesk 2026-05-22 commit `3f0c76c5`——旧值在新 SDK 是 `undefined`，传入 `options.scanTypes` 让 `startScanForResult` 以 BusinessError `code 401` 整体失败。AI 训练数据里几乎全用 `QRCODE`，必须显式覆盖
- **`05-best-practices/bridge-integration-pitfalls.md` §8 新增「Token / SecureStore 写入原子性」**：
  - `secureStore.set(refreshToken)` 必须**先**于 `storeAccessToken(...)`，因为后者 fire `tokenChangeListener` → bridge 推 `auth.access_token.set` → WebView 认为已登录
  - 一旦 SecureStore 写失败（HUKS / Keychain / EncryptedSharedPreferences），客户端会处于"当前会话已登录 + 下次启动无法 refresh + native panel 弹登录失败"三重矛盾态
  - 三端等价反模式都已写入文档，含 iOS / Android / HarmonyOS 各自的 SecureStore wrapper 与 file:line 引用模式
  - 来源：OctoDesk commit `c389ae1a`（fix(mobile): persist refresh token before firing access-token listener）
- **`05-best-practices/bridge-integration-pitfalls.md` §9 新增「HarmonyOS Pasteboard 提示时机」**：
  - HarmonyOS 6.x 起 `pasteboard.getData()` **每次**都弹系统级 toast，app 无法关闭
  - 在 `onForeground` / `aboutToAppear` / cold-start 第一帧前调用 = AGC 审核 P0 拒因 + 用户莫名其妙
  - 正确做法：仅在显式用户操作回调里读 + native 端 prefix 过滤（仅返回符合预期格式的内容，绝不把整段剪贴板给 WebView）
  - 来源：OctoDesk commit `4412ff12`（fix(mobile): stop eager desktop pairing clipboard peek）
- **`05-best-practices/bridge-integration-pitfalls.md` §10 新增「App-Linking 双侧配置 + EntryAbility 双入口路由」**：
  - HarmonyOS 深链接需要**三处同步**：`AppScope/well-known/harmony-app-linking.json` ↔ `entry/src/main/module.json5` ↔ `EntryAbility.onCreate` + `onNewWant` 双入口
  - 常踩错配：只 1+2 没 3 → cold-start 不走 deeplink dispatcher，WebView 停首页；只 2 没 1 → Domain Verify fail
  - 深入：OAuth callback 必须走系统浏览器（RFC 8252），不能用 ArkWeb 做 user-agent；客户端 dedup ring 作 defense-in-depth；literal host 二次校验
  - 来源：OctoDesk commits `43d7fa94`（Phase 1 Commit 3 — `/oauth/callback` deeplink）+ `2cfd0758`（Phase 3 Commit 15 — HarmonyOS OAuthPlugin）
- **`05-best-practices/bridge-integration-pitfalls.md` §11 新增「HMS ScanKit 接线层 trap」**：
  - 把 KIT-003 / KIT-004 之外、scanner 抓不到的"page-bound `UIAbilityContext`"问题写成文档：`startScanForResult(ctx, opts)` 的 ctx 必须从 `@Entry struct` 的 `getContext(this)` 取，EntryAbility 里那个裸 `AbilityContext` 会 `code 401` 失败
  - 错误码到 bridge outcome 的标准映射（`1000500001` / `1000500002` / `401`）
  - 来源：OctoDesk commits `28efd120` + `3f0c76c5`
- **§7 CSPRNG 段补 OAuth 2.0 PKCE 子场景**：
  - 显式点名"RFC 7636 PKCE verifier 必须来自 cryptoFramework"，这是 `CSPRNG-001` 最容易漏的真实子场景
  - 强调 silent fallback to `Math.random` 比直接 throw 更糟糕（客户端长期处于可攻击态而无告警）
  - 来源：OctoDesk commit `2c975529`（PKCE verifier 从 `Math.random` 改 `cryptoFramework.createRandom().generateRandomSync(32)`）
- **新增 `samples/templates/scan-qrcode/` 完整可跑骨架**：
  - `ScanPlugin.ets` + `RuntimeRegistry.ets` + `module.json5.patch.md` + README
  - 集成步骤、错误码映射表、反模式三例、上 PR 前 checklist
  - 内部跑 `bash tools/hooks/lib/scan-arkts.sh ScanPlugin.ets` exit 0
- **新增 fixture**：`BadHmsScanKit.ets`（exit=2，命中 KIT-003 + KIT-004）+ `GoodHmsScanKit.ets`（exit=0，验证 dual-import + `QR_CODE` 新名 + try/catch 不误命中）
- **README.md「接线层陷阱」一行**："8 类" → "12 类"（同步章节扩展）
- **回归**：`tools/hooks/test-fixtures/` 全部 11 个 fixture 跑通

### 2026-05-22 · LCC 真机部署反哺（layered icon 幽灵 + 9568297）

来自 LCC（化名，真鸿蒙 LLM 对话 app）v0.4.4 发布后第一次正经替换品牌图标 + 装机 MLR-AL10（HarmonyOS 6.1.0 / API 23）的实战：

- **`runtime-pitfalls/SKILL.md` § 十七「应用图标 layered icon · 三处资源 + foreground 必须真透明」**：
  - 现象：替换 `background.png` 后桌面 icon 显示叠加幽灵图案
  - 根因：DevEco 工程模板默认 `foreground.png` **不是真透明**——半透明白色四方格（RGB=255, alpha≈128–230, ~37.6% 像素非零 alpha），Read 工具肉眼看是空白
  - 修复：(1) 完整 icon 1024×1024 → 两处 `background.png`（AppScope + product）；(2) PIL 生成真透明 `(0,0,0,0)` PNG → 两处 `foreground.png`；(3) sips 256×256 → product `startIcon.png`
  - 验证脚本：`python3 -c "from PIL import Image; im=Image.open('foreground.png').convert('RGBA'); print(sum(1 for p in im.get_flattened_data() if p[3]!=0))"` 必须 0
  - 顺带覆盖了"资源在 AppScope + product 双份必须同步"这条相关坑
- **`build-debug/SKILL.md` + `references/develop-debug-build.md` 错误码表新增 `9568297`**：`install failed due to older sdk version in the device`——HAP `compatibleSdkVersion` 高于设备 OS API
  - 速诊：`hdc -t <id> shell param get const.ohos.apiversion` 查设备 API；HarmonyOS 6 编号对照（6.0.0=20 / 6.0.1=21 / 6.0.2=22 / 6.1.0=23 / 6.1.1=24）写进 SKILL 减少混淆——OS 子版本号 ≠ API 号
  - SKILL.md 激活条件加 `9568297`；hdc 命令段补三条设备 OS 探测 `param get`
- **`CLAUDE.md § 11.4` Top 7 → Top 8**：精华错误码段同步加 `9568297`
- **`docs/case-studies/llm-chat-app.md` M13**：新增"真机部署 · layered icon 幽灵 + 9568297 install 失败"节，沿用既有"症状 / 排查 / 修复 diff / 教训"四段式；总评 M3-M12 → M3-M13，运行时装配坑 7+ → 9+。M13 标号说明此节为 v0.4.4 发布后的运维期反馈而非原始里程碑
- **来源**：LCC `~/DevEcoStudioProjects/PrivateTalk` 真机部署 session（MLR-AL10 / HarmonyOS 6.1.0.117(SP6C00E115R1P4) / API 23）；首次走通"换品牌 icon + release 打包 + hdc 装机"完整链路时遇到的两类阻断

### 2026-05-15 · OctoDesk N2 / N3 二次反哺

来自 OctoDesk Mobile Companion `ai-now-phase-4` / `ai-now-phase-7` / `ai-now-phase-8` 三轮 commit 实战教训（OctoDesk Phase 4 N3 跨平台 capability 一致性 + Phase 8 反哺）：

- **`CSPRNG-002` scan-arkts 新规则**：`HUKS_TAG_IV` 同文件无 `cryptoFramework.createRandom` 时报 High。
  - 触发条件：文件含 `huks.HuksTag.HUKS_TAG_IV` 或 `HuksTag.HUKS_TAG_IV` AND 同文件不含 `cryptoFramework.createRandom` 引用 AND 无 `// scan-ignore: CSPRNG-002`
  - 来源：OctoDesk 2026-05-14 harmonyos-app-cleanup commit 修了一处 IV 从非 CSPRNG 取值的 SecureStore 实例。AES-GCM 的 IV 重复一次就完全 break，CSPRNG-001 只覆盖 `Math.random` 上下文，本规则补 HUKS IV 通道
  - inline-suppress 支持：`// scan-ignore: CSPRNG-002`（适用于 IV 来自可信跨文件封装的场景）
  - 实测：OctoDesk `apps/harmonyos/.../security/SecureStore.ets` PASS；反向构造（IV 来自 `Math.floor(Date.now())`）正确触发 High
- **`05-best-practices/bridge-integration-pitfalls.md` §1 新增"三端 granted 集合的跨平台一致性"段**：
  - 覆盖混合架构里 enum / granted / handler 三方在**单端**正确但**三端不一致**的 cross-cutting bug
  - 修复模式：跨平台 lint 脚本 regex 解析三端源文件 + 比较集合相等；PR gate 跑此脚本
  - "placeholder capability"（dispatcher fallthrough `CAPABILITY_UNAVAILABLE` 的）必须从 granted 显式剔除——即便 enum 里保留位
  - 来源：OctoDesk N3 实战（`scripts/check-native-capability-coherence.cjs` 跑 PR gate），三端 10 项 granted 一致性已上线校验

### 2026-05-14 · OctoDesk 实战教训沉淀

来自 OctoDesk Mobile Companion (`apps/harmonyos/`) 真工程接入 + N2 安全评审反馈：

- **`CSPRNG-001` scan-arkts 新规则**：`Math.random()` 在加密 / nonce / IV / signature 上下文里禁用。
  - 三档严重度判定：路径含 `/security/` 或 `/crypto/` → High；文件含 `cryptoFramework` / `nonce` / `aesGcm` / `huks` / `randomBytes` / `signKey` / `hmac` 等关键字 → High；否则 Medium 仅提醒。
  - 来源：OctoDesk N2 hard gate (`scripts/check-harmony-security.cjs`)，AES-GCM nonce 撞一次就完全 break，是评审中第一类阻断 issue。
  - inline-suppress 支持：`// scan-ignore: CSPRNG-001`。
- **`05-best-practices/bridge-integration-pitfalls.md` 新文档**：Web Bridge 接线层 8 类陷阱 + 反检查清单，scanner 抓不到但灰度才暴露的问题。覆盖：
  - Capability 握手 fail-closed（granted 必须由 handler 注册表派生，不能从 enum 派生）
  - `javaScriptProxy` / `WebMessageListener` 生命周期顺序
  - Mutating message 强制 `idempotencyKey`
  - Envelope schema 手工 validation（ArkTS 无 Zod）
  - hilog / 错误回执的敏感字段 leak
  - Picker URI 一次性、不要缓存（与 `ARKTS-DEPRECATED-PICKER` 联动）
  - CSPRNG 实战要求
  - 跨端注意（Android `WebMessageListener` 唯一通道、iOS `WKScriptMessageHandler` retain cycle）

### 2026-05-14 · 下游接入参考

OctoDesk 把 DevSpace 当**单一来源**接进了 monorepo，不复制脚本。集成方式可作为其他下游消费者的参考：

- `OctoDesk/.claude/settings.json` 注册 PostToolUse hook → `scripts/harmony-post-edit.sh`（薄 wrapper，scope 到 `apps/harmonyos/**`，delegate 到 `$HARMONYOS_DEVSPACE/tools/hooks/post-edit.sh`）
- `OctoDesk/scripts/harmony-dev-cycle.sh` 改为 `tools/harmony-dev-cycle.sh` 的 wrapper，注入 `--dir / --bundle / --ability` 默认值
- 通过 `HARMONYOS_DEVSPACE` 环境变量覆盖 DevSpace 位置，便于换机器 / CI
- OctoDesk `CLAUDE.md` Mobile Companion Boundary 段写明**反哺约定**：apps/harmonyos 开发中发现的可复用模式 / 规则 / 文档缺口必须当场反哺回 DevSpace（新增 scan-arkts 规则 / 追加 best-practices 段落 / 加 samples/templates），不积压到事后回顾。

### 2026-05-14 · Graduation 调整（让 DevSpace 对所有人可用）

诚实评估了首次反哺时混进的 OctoDesk-specific 字眼，做对外用通用化：

- `05-best-practices/bridge-integration-pitfalls.md` 去掉 `OctoDesk` / `octodeskBridge` / `shared/contracts/native-shell.ts` / `mobile-companion-architecture-deep-review §N2` 等出处特定字眼；底部加一段透明的"来源"footer 标明经验沉淀自一个真实下游项目，不影响通用性。
- `.claude/skills/arkts-rules/SKILL.md` 把 `CSPRNG-001` 加进规则 ID 速查段（之前只有 scan-arkts.sh 里有实现，下游 Cursor / Copilot 通过 SKILL.md 消费时拿不到）。
- 新增 [`samples/integrations/monorepo-consumer/`](samples/integrations/monorepo-consumer/) —— monorepo 子目录消费者接入指引：README + 两个 wrapper 模板（`harmony-post-edit.sh.template` / `harmony-dev-cycle.sh.template`），改 1-3 行 config 即可用；包含 token 成本实测数据与降噪方案。这是 OctoDesk 接入模式的脱敏抽取，原作为下游 best practice 参考。
- README 加 monorepo-consumer 链接到"接线层陷阱"段同一区域，便于 monorepo 形态的访问者直接找到。

### 2026-05-14 · 提案：autoresearch 启发式自动进化（discussion，未采纳）

Draft RFC: [`docs/PROPOSAL-2026-05-14-autoresearch-style-evolution.md`](docs/PROPOSAL-2026-05-14-autoresearch-style-evolution.md)。诚实评估 DevSpace 各组件是否适合套 karpathy/autoresearch 的"单文件 mutation + 标量 fitness + git keep/discard"模式。结论：

- **scan-arkts 规则进化**适配最好（F1 on labeled corpus 是清晰的 fitness）
- **samples/templates 自动新增**次之（compile + scan-arkts clean 是离散布尔 fitness）
- 基础设施脚本 / 知识库 / AI 指令文件**强烈不适配**（fitness 不可观测、破坏成本高）
- 短期高 ROI 替代方案：codify 反哺约定（已做）+ 半自动候选规则建议脚本

文档不锁定路径；待后续决定是否启动 Phase 1（语料标注 + evaluator 落地）。

### v0.4.5 同步修正（推送前 review 发现）

- `.claude/skills/manifest.json` v0.4.3 → v0.4.5（与 `package.json` 同步；runtime-pitfalls triggers 补 layered icon / NavPathStack / per-host store 三组关键词）
- `llms.txt` 当前版本 v0.3.0 → v0.4.5；"7 类工程装配陷阱" → "17 类"；samples/templates 段拆"基础 4 个 + 进阶 4 个"
- `README.md` Recipe Templates 4 个 → 8 个；Case Studies M3-M12 / 11 节 → M3-M13 / 12 节 + 增列 `android-parity-migration.md`
- `CLAUDE.md § 2.5` / `AGENTS.md § 0.4` runtime-pitfalls 行 "7 类" → "17 类（含 NavPathStack 白屏 / emoji 渲染 / Button padding / build() 单 root / timeline timestamp / per-host store / daemon workspaceId / layered icon foreground 透明）"；激活关键词加"替换品牌图标（layered icon）"
- `samples/templates/README.md` 顶部"4 个高频小场景" → "8 个（基础 4 + 进阶 4）"
- `.claude/skills/runtime-pitfalls/SKILL.md` frontmatter `verified_against` 2026-05-07 → 2026-05-22；来源 M3-M12 → M3-M13 + paseo-harmony Phase A/B；激活条件加 layered icon / NavPathStack / build() root / timeline / per-host store / workspaceId 关键词
- `.claude/skills/arkts-rules/references/spec-quick-ref.md` 第四节补全 `CSPRNG-001` / `CSPRNG-002` / `KIT-003` / `KIT-004` 四条规则速查行（之前只在 scan-arkts.sh 实现，AI 通过 spec-quick-ref 检索时拿不到）

## [0.4.4] - 2026-05-11

AI Agent CLI 调试闭环 patch：

- **`tools/harmony-dev-cycle.sh` 分层命令**：
  - `quick-check`：轻量 ArkTS/OHPM 扫描，不依赖 DevEco
  - `build-check`：`ohpm install → hvigorw codeLinter → assembleHap`
  - `cycle-once`：`build → install → run → 抓有限时长 hilog`，默认 8 秒，适合 Claude Code / Codex 读取
  - `device-check`：复用已有 HAP，安装、启动并抓 hilog
  - `cycle` 保留长流日志模式，给人工调试用
- **安装链路补齐**：`tools/install.sh` 现在会把 `harmony-dev-cycle.sh` 和 `run-linter.sh` 一起安装到用户 app 项目，安装完成提示 CLI 调试闭环命令。
- **npm 包补齐**：`package.json` `files` 加入 `tools/harmony-dev-cycle.sh` 与 `tools/scaffold-deveco-project.sh`，避免 npm/npx 用户拿不到 README 宣称的核心脚本。
- **文档同步**：README、`04-build-debug-tools/README.md`、`docs/USER-GUIDE.md` 同步说明 `quick-check / build-check / cycle-once / device-check` 的推荐用法。

## [0.4.3] - 2026-05-07

文档用户友好性 patch（无代码 / 行为变更）：

- **README 重写**：第一屏从 30 行版本契约 yaml 改为"价值 + persona + 一行装命令"
  - 新增 "这个项目对谁有帮助？" 段（vibe coder / 老开发者 / 团队 lead 三类 persona）
  - 新增 "装了能解决什么问题？" Before/After 对比表（6 项可量化痛点：ArkEval 3.13% 基线、21%→0% 假阳率、AI 瞎编 OHPM 包、状态不刷新等）
  - "30 秒装好" + "5 分钟试一下（验收装好）" 提到第一屏
  - 版本契约 yaml 后置到 § 8
- **新文档 `docs/USER-GUIDE.md`**（583 行使用说明书）：
  - 1. 首次使用：5 分钟验收
  - 2. 第一次让 AI 改一个页面（3 种 AI 助手 prompt 模板）
  - 3. 日常工作流（Claude Code / Codex CLI / Cursor / Copilot / 纯手写）
  - 4. 典型任务怎么做（8 场景：写新页面 / 加权限 / 接 LLM API / 长列表 / 深色模式 / 编译失败处理 / scanner 误报 / OHPM 告警）
  - 5. AI 协作"魔法咒语"（7 个 prompt 模式让 AI 充分用规则）
  - 6. 故障排查（7 类常见问题）
  - 7. 团队协作 / CI（git 入库 / GitHub Actions / pre-commit / 自定义规则）
  - 8. 升级与卸载（manifest 安全模式 + 强制模式说明）
- **`docs/USAGE-GUIDE.md`** 顶部加引导，明示三份文档关系：
  - `README.md` = 装好 + 5 分钟验
  - `USER-GUIDE.md` = 日常使用说明书
  - `USAGE-GUIDE.md` = 进阶（多 app 共享 / 三层发布 / 同类对比）

让 npm 用户在 npmjs.com 看到新封面 README + USER-GUIDE 引导（v0.4.2 npm 上仍是旧文档，v0.4.3 publish 后同步）。

## [0.4.2] - 2026-05-07

uninstall 兼容性 patch（v0.4.1 真用户路径测试时发现）：

- **修变量边界 BUG**：`tools/install.sh:174` 与 `:339` 的 `$VAR紧贴中文` 在某些 bash 版本下会把全角字符当成变量名一部分（实测 npx 跑时报 `MANIFEST_FILE�: unbound variable`）。改用 `${VAR}` 显式定界。
- **uninstall 后 .claude/ 空目录残留**：v0.4 用一组硬编码 `rmdir` 列表，但子目录如 `.claude/skills/X/references/` 删完文件后仍有空目录链导致父 rmdir 失败。改用 `find ... -depth -type d -empty -delete` 递归清空。
- 实测：装 + 卸载后只剩用户原 CLAUDE.md，所有本工具写入的文件 + 空目录全清。

## [0.4.1] - 2026-05-07

打包卫生 patch（v0.4.0 npm publish 时被 OTP 拦下顺手发现）：

- 加 `.npmignore` 排除运行时产物 `.claude/.harmonyos-last-scan.txt`（钩子写入的临时文件，不该进 npm 包）
- 精化 `package.json` `files` 字段：`.claude/` → `.claude/settings.json + .claude/skills/`、`tools/hooks/` 按子项明列；GitHub 上 npm 用户拿不到 docs/archive、upstream-docs、samples（这些通过 git clone 获取）
- 包大小不变（113 kB），但 51 文件（v0.4.0 包是 52，少 1 个 last-scan.txt）

## [0.4.0] - 2026-05-07

第六轮评审（Codex 视角）反馈驱动。**install 安全 + 真回归测试 + V1/V2 默认统一 + OHPM 网络错误分类**——这一轮的主题是把 v0.3.0 已经能跑的工具变成"敢在真实工程跑"的工具。

### Breaking · install/uninstall 行为重构（评审 P1-1 + P1-2）

v0.3 的 install 见已存在文件就跳过、uninstall 直接删——形成不对称：用户已有 CLAUDE.md 时 install 不接管（用户以为生效），uninstall 却把它删了（用户原配置丢失）。

v0.4 修复：

- 加 `.harmonyos-ai-workspace.manifest` 文件，install 时**逐文件记录** `<status>\\t<path>\\t<sha256>`：
  - `written` —— 本工具实际写入
  - `skipped` —— 已存在被跳过（绝不动）
  - `failed` —— 下载失败
- uninstall **只删 manifest 标记为 written 的文件**，且校验 sha256：
  - sha256 不一致（用户改过该文件） → 保留并 warn（除非 `--force`）
  - manifest 不存在 → 拒绝卸载（防误删用户原文件）
- install 末尾出**安装报告**：明示哪些写入、哪些跳过、哪些失败；跳过列表附"如何接管这些文件"提示

### 新功能

- **`--dry-run`**：列出将要写入的文件清单不真写（CI 友好、新手验收）
- **`--force`**：覆盖已存在文件（接管模式）
- **`tools/test-suite.sh`**：真回归测试套件，`npm test` 调用，19 项断言（fixture exit / sample template / JSON / --stats / OHPM fixture / install dry-run）。v0.3 的 `bash xxx \|\| true` 只能证明脚本能跑，证明不了规则正确。

### 修复

- **PostToolUse 钩子路径加双引号**（评审 P1-3）—— `bash $CLAUDE_PROJECT_DIR/...` 在含空格的项目路径下会炸；`.claude/settings.json:10` 改为 `bash "$CLAUDE_PROJECT_DIR/..."`
- **CLAUDE.md V1/V2 默认策略与 AGENTS.md / state-management SKILL 统一**（评审 P1-4）—— v0.3 时 CLAUDE.md 说"新项目用 V2 更安全"但其他 3 处入口都说"默认 V1"，AI 会读到矛盾指令。v0.4 把 CLAUDE.md 改为"默认 V1（生态最成熟、DevEco 模板默认）"；附跨文件 reference 链接保持一致性
- **OHPM 网络错误分类**（评审 P2-2）—— v0.3 把 `ohpm view` 任何失败都归类 OHPM-FAKE High 阻断 AI;v0.4 区分 not-found / network / unknown：
  - 含 `not found` / `404` / `does not exist` → `OHPM-FAKE · High`（真假包，阻断）
  - 含 `etimedout` / `econnrefused` / `502` / `503` / `network` / `timeout` 或 `timeout` cli 退出 124 → `OHPM-NET · Low`（网络错，**不阻断**）
  - 其他 → `OHPM-UNKNOWN · Medium`（保守降级）
  - `ohpm view` 加 15 秒 timeout 防卡死

### 文档

- **README 版本契约重构**（评审 P2-1）—— v0.3 单行 `harmonyos: ">= 6.0.0  (API >= 12, 推荐 21/22)"` 让人误以为 API 12 属于 HarmonyOS 6。v0.4 拆为：
  ```
  min_supported_api / current_consumer_stable / first_stable_release /
  developer_preview_api / recommended_target / recommended_min
  ```
  并加引导段说明"API 编号才是单一权威，看 API 数字最准"
- **HarmonyOS 6.1 dev beta → API 23 Developer Beta**（评审 P2-1 配套）—— "6.1" 的措辞和华为发布节奏对齐性差；改为引用更稳定的 API 23 编号；CLAUDE.md / llms.txt 同步
- **README 加"编译失败时怎么把信号传给 AI"段**（评审建议 5）—— vibe coding 用户最大痛点是 AI 拿到错误后瞎猜；给出复制 hvigorw 错误 + 引用 spec-quick-ref.md 的精确路径

### 内部

- `package.json` 0.3.0 → 0.4.0；files 数组加 `tools/test-suite.sh`
- `tools/install.sh` 全面重写（约 100 → 270 行），保留所有 v0.3 入口参数

### 评审采纳总览

Codex 评审给的 7 项建议中：
- P1-1 / P1-2 install 可信度：✅ 采纳，manifest + checksum + dry-run + 安全 uninstall
- P1-3 hook 路径加引号：✅ 采纳
- P1-4 V1/V2 矛盾：✅ 采纳，CLAUDE.md 改为默认 V1
- P2-1 版本契约误读：✅ 采纳，拆开 + API 23 措辞
- P2-2 OHPM 网络误判：✅ 采纳，分类 + timeout
- P2-3 JSON5 启发式解析：⏸ v0.5 候选，工作量大且实际 oh-package.json5 99% 用引号 keys，marginal
- 长期改进 1（manifest+checksum）/ 3（npm test 真断言）/ 5（vibe coding 入口）：✅ 全采纳
- 长期改进 2（platform-matrix 单源）/ 4（CI 严格模式 / shellcheck）/ 6（API 索引）/ 7（样例可粘贴二次核对）/ 8（竞品矩阵 checked_at）：⏸ v0.5 候选

## [0.3.0] - 2026-05-07

跨 v0.2 → v0.7 的首个 SemVer 干净 release：scan-arkts 13 → 31 条规则、新增 PostToolUse 钩子 + 装饰器上下文检测 + 真 collapse + inline-suppress + `--stats` 模式 + 多个新 SKILL（runtime-pitfalls / multimodal-llm / web-bridge / harmonyos-review）+ 4 recipe template + check-rename-module 工具。详见下方分轮记录。

### LCC 四轮实测反馈 · v0.7 修复（2026-05-07）

第四轮 PrivateTalk 真工程实测 v0.6 7 项修复全部生效（假阳率 21% → 0%），但发现 **2 处装饰器边界漏报 + 1 处文档空白**。**全部采纳**：

**P0 漏报**（v0.6 awk 状态机覆盖不全）：

- **同行装饰器 + struct 漏识别** —— `@Entry @Component struct Page {` 这种 DevEco 模板/简写常见形式，v0.6 awk 第一条规则 `next` 跳过该行让 struct/class 检测永不命中，导致整个 ArkUI 类被识别为普通类，类内 `this.X.push()` 全部漏报。修：去 `next`，新增 `inline_re` 同行复合规则；保留单独装饰器行的旧路径。
- **`@CustomDialog` / `@Reusable` 不在白名单** —— 这两类装饰器修饰的 struct 同样是响应式的（弹窗参与重渲染、Reusable 池化时需状态同步），v0.6 漏白名单导致组件内 mutation 不报。修：装饰器名单从 5 个扩到 7 个，提到顶部变量 `ARKUI_DECORATORS` 便于后续扩展。

合并修法（一次性补两处缺口）：

```awk
ARKUI_DECORATORS='Component|ComponentV2|Observed|ObservedV2|Entry|CustomDialog|Reusable'
# 同行装饰器 + struct/class 直接 set in_arkui（不 next）
($0 ~ /^[[:space:]]*@/) && ($0 ~ sc_re) {
  if ($0 ~ arkui_re) { in_arkui = 1; pending = 0; depth = 0 }
}
# 单独装饰器行（仅当本行没有 struct/class 时 next）
($0 ~ dec_re) && ($0 !~ sc_re) { pending = 1; next }
```

**P1 文档空白**：

- **inline-suppress 机制全仓库 0 处文档** —— v0.5 加了 `// scan-ignore: <RULE-ID>` / `// scan-ignore-line` 两种标记，v0.6 才把 `scan-ignore-line` 严格隔离为同行匹配，但 README / AGENTS / CLAUDE / 任何 SKILL 都没说明用法和差异，用户只能读源码发现。修：`arkts-rules/SKILL.md` 新增 § "抑制 scanner 误报（inline-suppress）" 段，含完整对照表 + 例子；README 规则编号体系表格加锚点链接。
- 同步修正 `arkts-rules/SKILL.md` 第 97 行的 Configuration import 复述错误（之前还说"Configuration 不在顶层"，与 v0.6 已修正的 runtime-pitfalls §九 自相矛盾）。

**inline-suppress 行为决策**：

评审者建议两选——A 让 `scan-ignore-line` 也支持上一行（统一行为）/ B 改名 + 文档。**采纳 B 的"补文档"路径，不动行为**：

- v0.6 才修过 v0.5 的串行 BUG（前一行有 `scan-ignore-line` 误抑制下一行），回退会重新引入
- `scan-ignore-line` 字面"line" 指当前行最自然，跨行抑制本就该用具名 `scan-ignore: <RULE-ID>`
- 命名歧义靠文档解决——SKILL 表格 + 例子 + 一段⚠️ 说明清楚

**新增 fixture**（验证回归）：

- `tools/hooks/test-fixtures/InlineDecorators.ets` —— `@Entry @Component struct` 同行写法
- `tools/hooks/test-fixtures/CustomDialogState.ets` —— `@CustomDialog struct` 类内 mutation
- `tools/hooks/test-fixtures/ReusableState.ets` —— `@Reusable @Component struct` 同行 + 类内 mutation

回归覆盖：9 个 fixture（8 Bad + 1 Good，全部 exit 符合预期）+ 4 个 sample template（全部 clean）+ 2 个反测试（普通 class / 非 ArkUI 装饰器，正确不误报）。

**版本号同步**（评审 #4）：

- `package.json` 0.2.5 → 0.3.0（v0.2.x 后续 patch 合到 v0.3.0 minor）
- CHANGELOG `[Unreleased]` 段切到 `[0.3.0] - 2026-05-07`
- 按 SemVer：scan-arkts 规则数 13 → 31、新增多个工具与 SKILL，向前兼容的功能扩展属 minor bump

### 历史累积分轮记录（v0.2 → v0.6 全部合并到 0.3.0）

> 下面是 v0.3.0 release 之前的所有评审循环、PR 批次、第三方反馈的详细记录，按主题/轮次分组。新读者可跳过；评审审计 trail 用。

#### v0.2.x post-review patches

- **v2 评审响应**（详见 [`docs/archive/reviews/2026-05-06-v2-claude.md`](docs/archive/reviews/2026-05-06-v2-claude.md)）：
  - `scan-arkts.sh` 13 → 18 条规则（+ KIT-001 / PERF-001 / ARKTS-016 / STATE-009 / SEC-001 / COMPAT-001）+ `--json` 输出模式
  - OHPM 黑/白名单拆到 `tools/data/ohpm-{blacklist,whitelist}.txt`（26+22 项）
  - `tools/hooks/examples/` 跨工具 hook 接入示例（Codex/Cursor pre-commit / Copilot 占位 / GitHub Action CI）
  - `docs/MCP-INTEGRATION.md` 接入第二个 MCP server（动作型，hdc 控设备）的指引
  - `tools/bootstrap-upstream-docs.sh` 加交互式 y/N 提示（默认不拉 2.7 GB）
  - README "核心差异化"重写为 5 条真独占能力 + 4 层规则编号体系精确说明
- **新手向导**：
  - `tools/setup-from-scratch.sh` 半自动主入口（基础工具→DevEco 引导→PATH→Claude Code→装规则→钩子自测）
  - `docs/SETUP-FROM-SCRATCH.md` 详细引导文档（macOS 干净到 hello world，30-60 分钟）
  - `verify-environment.sh` 每个失败项给"下一步建议"，OpenHarmony 文档镜像降为可选
  - `install.sh` 装完检测 Claude Code / DevEco 缺失并提示
- **v3 评审响应**（详见 [`docs/archive/reviews/2026-05-07-claude.md`](docs/archive/reviews/2026-05-07-claude.md)）：
  - **第一轮**（B-fix + C-3）：
    - `post-edit.sh` 退出码语义修正：High → exit 2（block + 反馈给 AI），Medium → exit 0（让 AI 看见但不阻塞），消除"Medium 级 exit 1 让 Claude 看不到反馈"的隐性 bug
    - `.mcp.json` 改 `npx -y mcp-harmonyos@latest`：fresh clone 不再需要先全局装 npm 包
    - **版本契约**：README 顶部加 yaml `targets:` 段；5 个 SKILL.md frontmatter 加 `verified_against: harmonyos-6.0.2-api22`
  - **第二轮**（G-1 / C-1 / C-2 / C-4 / E-1 / E-2 / X-2 全部采纳）：
    - **G-1 CLAUDE.md 瘦身**：650 → 484 行；§ 11-13 详细内容（150 行）拆到新建的 `.claude/skills/build-debug/references/develop-debug-build.md`，CLAUDE.md 保留高频精华
    - **C-1 ArkTS 规范快查**：新建 `.claude/skills/arkts-rules/references/spec-quick-ref.md`：14 ARKTS / 6 STATE / 4 KIT/PERF/SEC/COMPAT 条规则映射到官方规范条款 + 正确写法表；arkts-rules SKILL.md 顶部强调"必须引用 ID 而非凭印象"
    - **C-2 state-management V2 强化**：SKILL.md 加 6 个完整 V2 范例（覆盖 11 装饰器）+ V1→V2 决策树 + 5 条 V2 反模式
    - **C-4 钩子 timeout**：post-edit.sh 加 `timeout 10`（gtimeout fallback），超时返回 124 → 不阻塞 AI 流程
    - **E-1 AGENTS.md 重定位为通用宪法**：标 [agents.md 标准](https://agents.md/) 24+ 工具兼容；CLAUDE.md 顶部加"通用宪法见 AGENTS.md"，冲突以 AGENTS.md 为准
    - **E-2 ID 体系收口**：harmonyos-review report-template 强制要求所有 finding 用稳定 ID 引用；列出 9 大命名空间 88 条规则 + 引用格式示例
    - **X-2 README 一图流**：加 ASCII art 流程图：AI 启动 → 钩子触发 → stderr 反馈 → AI 自我修正

#### v0.2.x 后续 patch（v0.3 提前实施 · 2026-05-07）

逐条评估 v0.3 候选清单后，**3 件"完全自主可控、对真实开发者立即有用"的提前做完**：

- **A · scan-arkts.sh 18 → 25 条**（高把握 grep 规则，假阳性低）：
  - `SEC-002` hilog `%{public}` 输出敏感字段（token / password / 身份证）
  - `SEC-007` 弱算法（MD5 / SHA1 / DES）
  - `DB-001` ResultSet / RdbStore 未 close
  - `KIT-002` ImageSource 解码后未 release
  - `AGC-RJ-014` UI 中文字符串硬编码（应走 `$r('app.string.xxx')`）
  - `PERF-002` 长列表用 ForEach 而非 LazyForEach
  - `STATE-006` V1 `@Link` 调用方丢 `$$`
  - 配套 fixture：`tools/hooks/test-fixtures/BadSecurityKit.ets`
  - `spec-quick-ref.md` 同步更新 ID 映射表

- **B · 4 个 Recipe 模板**（`samples/templates/`）：
  - `permission/` 完整代码：4 类常见权限（位置 / 相机 / 通知 / 麦克风）的运行时申请 + UI 解释 + 拒绝兜底
  - `list/` 完整代码：LazyForEach + IDataSource + 下拉刷新 + 上拉加载
  - `dark-mode/` 完整代码：系统主题跟随 + 资源限定符 + mediaquery 监听
  - `login/` 指引型（不写完整代码）：华为账号 SSO API 在 12 → 22 多次变化，AI 训练数据是旧版；只给"约束 + 文档链接 + 反模式提醒"避免误导

- **C · npm 薄 CLI**（`package.json` + `bin/cli.js`）：
  - 让 `npx -y github:Octo-o-o-o/harmonyos-ai-workspace` 直接可用，不必先 npm publish
  - 透传所有 `tools/install.sh` 参数（`--targets` / `--mirror` / `--uninstall`）
  - Windows 检测：明示走 WSL，不试图在 native 上跑
  - npm publish 后等价 `npx harmonyos-ai-workspace`

#### v0.3 仍候选（依赖外部 / 内容工程半衰期短，等真用户反馈）

- 接入动作型 MCP 默认装（替代 docs/MCP-INTEGRATION.md 指引）—— G 半年未更新
- PowerShell 版本（Windows native）—— 多走 WSL
- Layer 2 抽出 Claude Plugin 独立仓库
- starter-kit 完整业务模板（不止 4 recipe）—— 取决于鸿蒙 API 稳定度
- SDK recipe 第三方贡献规范 —— 需先有 1-2 真实 recipe
- RAG MCP serving 13524 docs —— 独立项目级

#### LCC 二轮真工程实测反馈响应 · BUG 修 + 误报修 + 体验

二轮反馈来自评审者在 PrivateTalk 真工程跑 30 条扫描规则 + check-rename-module.sh 后的实测数据：1 个真 BUG / 3 条规则真误报（21% 假阳率）/ 3 类体验问题。**全部采纳**：

**P0 真 BUG**：

- `check-rename-module.sh` json5_to_json 未处理尾逗号 → 在 DevEco 默认模板（`buildModeSet: [{ name: 'debug', }, ...]`）上 jq 直接 parse error 失败。**任何用 DevEco 6.x 模板的工程都触发**。修：sed 加两条规则去 `}` 和 `]` 前的尾逗号。

**P1 真误报**（去 23/111 假阳，假阳率 21% → 接近 0）：

- `STATE-009` 误把 `this.prefs.delete()` / `this.rdbStore.delete()` 当 Map/Set 状态 mutation 报。修：排除常见非状态字段名前缀 `prefs|store|rdb|cache|client|controller|ctx|context|db|registry|abilityCtx|httpReq|connection|listener` —— 这些是已知的 KV/DB/MCP API 持有者。
- `ARKTS-003` 在 `Record<string, Object>` 上的索引赋值（OpenAI Vision payload 标准模式）误报 12 处。修：扫到 `obj['k']` 时检查同文件有无 `var: Record<...>` 或 `var: Map<...>` 声明，有则跳过。
- `ARKTS-RECORD` 把空字面量 `: Record<...> = {}` 误报为违规（实际编译过）。修：模式从 `\{` 改成要求至少一个键值字符 `\{\s*['"a-zA-Z_]`，仅含键值对的字面量才报。

**P2 体验**：

- **inline-suppress 机制**：用户可在违规上一行或同行写 `// scan-ignore: <RULE-ID>` 抑制该次命中（也支持 `scan-ignore-line` 跳过整行所有规则；`scan-ignore: RULE1, RULE2` 跳过多条）。emit_high/emit_med 入口检查，被抑制的不计数也不输出 → 真"逃生口"。
- **删除 STATE-006**：评审者实测此规则启发式不足（"看 @Link 就把所有 SomeComponent({...}) 报"），grep 跨语义不够。删掉规则；让 state-management SKILL 文档教即可。如需重新启用须接 ts-morph / tree-sitter。
- **collapse hint**：单文件命中 ≥5 条时自动给"加 scan-ignore 抑制"提示。JSON 模式（CI）不影响完整数据。

**P3 文档**：

- `runtime-pitfalls` § 二 措辞修正：`useNormalizedOHMUrl` "HarmonyOS 5+ 默认开启" → "HarmonyOS 6 IDE 模板 / DevEco 5.0+ 默认开启；HarmonyOS 5 时代多数模板也是 true，可手动设 false"。
- `runtime-pitfalls` § 三 强调 build-profile.json5 `modules[].name` 与 module.json5 `module.name` **逐字符等于**关系（含报错原文 + OHPM 包名是另一层的澄清）。
- `runtime-pitfalls` § 九 重写"常用 Kit 类型 import 速查表"：12 类常用类型对应 import 来源，含 `Configuration` 在 `@kit.AbilityKit` 顶层（不在 ConfigurationConstant 命名空间）。
- `build-debug` 终端环境变量段升级为"5 个必设 + sanity check"，含报错原文 `00303217 Configuration Error`。
- `case-studies/llm-chat-app.md` 顶部加"范型化声明"——明确"具体里程碑章节是从真用户反馈中提炼的代表性案例，不一定 1:1 对应"，避免读者把 case study 当考古实录。M9 章节标题改为"资源句柄释放范式"，明示 LCC 当前 BackupManager 走 KV 而非 RDB。

**新 fixture**：

- `tools/hooks/test-fixtures/GoodPrefStore.ets` —— 4 类合法代码（preferences.delete / Record 索引赋值 / 空 Record 字面量 / 带 scan-ignore 的资源清理 catch）应**全部 0 命中**，验证误报修复。

#### 真实战反馈响应 · LCC（LLM Chat Client）M3-M12 实战踩坑全采纳

第一次真实用户反馈来自一个真鸿蒙 LLM 对话客户端 app 的 M3-M12 多里程碑实战。15 条具体踩坑里 12 条是真痛点，**全部采纳**：

- **scan-arkts.sh 25 → 30 条**（5 条新增高把握 grep）：
  - `ARKTS-RECORD` · `Record<K,V>` 字面量初始化也违反 `arkts-no-untyped-obj-literals`
  - `ARKTS-AWAIT-TRY` · 文件含 await 但全文无 try 块（codeLinter 报"Function may throw"）
  - `ARKTS-DEPRECATED-PICKER` · `picker.PhotoViewPicker` 在 HarmonyOS 6 已弃用
  - `ARKTS-DEPRECATED-DECODE` · `util.TextDecoder.decodeWithStream` 已弃用
  - `ARKTS-NO-UNION-CONTENT` · ArkTS 不支持 `string | object[]` union（OpenAI Vision 类场景）
  - 加 `STRING-JSON-EMPTY` · `string.json` 数组不允许为空（仅命中该路径文件）
  - 配套 fixture：`tools/hooks/test-fixtures/BadRuntimePitfalls.ets`

- **新增 3 个 SKILL**：
  - **runtime-pitfalls** · 7 类工程装配陷阱（主题切换 / `useNormalizedOHMUrl` / 模块改名 3 处同步 / `string.json` 空数组 / Web `javaScriptProxy` 稳定实例 / HUKS 加密 / `DEVECO_SDK_HOME`）
  - **multimodal-llm** · LLM 客户端领域专项（union content 拆双字段 / SSE 流式 buffer 拼接 / multipart 上传 / DALL-E base64）
  - **web-bridge** · ArkUI Web 组件 + H5↔ArkTS 桥（`javaScriptProxy` 稳定实例 / `runJavaScript` 时序 / Markdown 离线渲染器 / `ResizeObserver` 高度自适应）

- **新增工具**：
  - `tools/check-rename-module.sh` —— 自动校验 `build-profile.json5` × `module.json5` × `oh-package.json5` 三处模块名一致

- **新增文档**：
  - `docs/case-studies/llm-chat-app.md` —— LCC M3-M12 实战工程笔记（**症状 / 错误信息 / 修复 diff / 教训** 四段式）

- **同步更新**：
  - `arkts-rules SKILL.md` 加"高频踩坑 5 条"段（Record 字面量 / await 不在 try / Configuration 命名空间 / union 字段 / 弃用 API）
  - `build-debug SKILL.md` 加 `DEVECO_SDK_HOME` 配置 + OHPM 502 兜底
  - `manifest.json` 注册 3 个新 skills，version 1.0.0 → 1.1.0
  - `install.sh` 装机时拉新 skills + references
  - `tools/generate-ai-configs.sh` fan-out 把 runtime-pitfalls 加入（领域专项保持按需触发不强制 fan-out）
  - `.cursor/rules/harmonyos.mdc` + `.github/copilot-instructions.md` 重新生成（505 → 733 行）

**未采纳**（明确 v0.3+）：
- llm-chat-mvp 完整脱敏脚手架 —— 需用户提供 LCC 脱敏代码，本仓库不能拍脑袋 AI 生成
- `--auto-fix` 模式 —— DevEco IDE 已有；CLI 自动改写假阳性风险高

#### codex 评审响应（详见 [`docs/archive/reviews/2026-05-07-codex.md`](docs/archive/reviews/2026-05-07-codex.md)）

第三轮评审（codex 视角，源码 + WebFetch 八仓基线）。**P0 全部立即采纳**：

- **README curl 命令补全** · 三处 `curl -fsSL ...` 占位换成完整 URL，新手可直接复制
- **install.sh 补拉 OHPM 数据文件** · 加 `fetch tools/data/ohpm-{blacklist,whitelist}.txt`，避免 fresh clone 退化为内联兜底
- **`.DS_Store` 物理清理** · 删除 root / tools / tools/hooks 下的 .DS_Store（核查发现未被 git tracked，但避免 macOS 后续误 add）
- **评审归档** · `docs/REVIEW-2026-05-*.md` → `docs/archive/reviews/`（按 `日期-轮次-评审者` 命名）+ 加 README INDEX，clone 首屏不再被复盘文件淹没
- **CLAUDE.md § 14 任务模板挪到 USAGE-GUIDE.md** · 是给用户跟其他 AI 提需求时用的低频内容，不该每轮注入到 Claude 上下文
- **README 内置内容段压缩** · 13 条二级 bullet 压成 8 条精炼描述，节省 39 行

评审错判核查后澄清：
- "PLAN.md 与 docs/PLAN.md 重复" → root **没有 PLAN.md**（v1 已迁移）
- "`.cursor/rules/harmonyos.mdc` 未入库" → **已入库**（git ls-files 可见）
- "`.mcp.json` 改 npx -y" → **早已实施**（v3 第一轮）

详细处置决策见评审顶部 `## 处置决策表`。

#### LCC 三轮实测反馈 · v0.6 修复（2026-05-07）

第三轮 PrivateTalk 真工程实测反馈：v0.5 自查发现 **1 个 P0 真 BUG / 1 处 SKILL 自相矛盾 / 2 条规则系统性误报 / 1 处折叠形同虚设**。**全部采纳**：

**P0 真 BUG**：

- `check-rename-module.sh` v0.5 用 BSD sed 处理尾逗号无法跨行 → 实测对默认 DevEco 模板 0 用（`,\n },\n ],\n}` 这种合法 JSON5 仍 jq parse error）。**任何用 DevEco 6.x 模板的工程都触发**。修：换成 `perl -0pe`（slurp 模式让 `\s` 匹配换行）一行解决；perl 缺席时 fallback GNU sed 多行模式。验证：在合成模板上正确解析含跨行尾逗号的 build-profile.json5。

**SKILL 自相矛盾**：

- `runtime-pitfalls` § 九 "Configuration 类型 import" 段 ❌/✅ 互换 —— 顶部说"❌ Configuration 来自 @kit.AbilityKit 顶层"，但同一 SKILL 的速查表又说"Configuration 在 @kit.AbilityKit 顶层"。实测编译器报错原文：`Namespace 'ConfigurationConstant' has no exported member 'Configuration'`。修：重写该段，明确 `Configuration` 是 @kit.AbilityKit **顶层** export，**不在** ConfigurationConstant 命名空间下。

**P1 系统性误报**：

- `STATE-002` / `STATE-009` 误把**普通工具类**（IDataSource / Store / EventBus / SecretStore / RdbAdapter）的 `this.X.push()` / `this.prefs.delete()` 当 ArkUI 状态 mutation 报。讽刺：项目自家 `samples/templates/list/item-data-source.ets`（标准 IDataSource 实现）被自家 lint 拒绝。v0.5 用 EXCLUDE_NAMES 前缀白名单是补丁；v0.6 改用**装饰器上下文检测**——awk 状态机扫文件，记录 `@Component / @ComponentV2 / @Entry / @Observed / @ObservedV2` 装饰的 class/struct **完整花括号区间**。STATE-002/009 仅在 ArkUI 类内部触发，普通 class 永不报。

- `PERF-002` 原"文件 > 80 行"启发式 91% 假阳率（评审者实测：12 个 ForEach 仅 1 个值得换 LazyForEach；setting 子页文件 200 行但数据源只有 3-5 项）。改为**数据源名启发式**：仅当 ForEach 第一参数标识符匹配 `messages|conversations|posts|feed|items|logs|records|history|comments|threads|notifications|chats|users|contacts` 时报，且要求文件不含 LazyForEach。

- `ARKTS-016` 空 catch 块 v0.5 报 High 级，实测 15 处仅 ~2 处真问题（其余是 cleanup/destroy/unlink 容错或 JSON.parse fallback）。降为 Medium；仅在文件**含 await** 时触发（异步上下文吞错风险更高）；reason 加"如果是 cleanup 容错可加 scan-ignore: ARKTS-016"。

**P2 折叠**：

- v0.5 加了 collapse hint 但**没真折叠** —— i18n DICT 文件 53 条 AGC-RJ-014 全输出仍刷屏。v0.6 实现真折叠：同文件同规则前 3 条原文输出，后续聚合为 `[+RULE-ID] N more in this file (use scan-ignore: ... to silence)`。JSON 模式不动（CI 要全部数据）。

**P3 体验**：

- 新增 `--stats` 模式：仅按规则汇总命中数（CI 友好）。退出码与文本模式一致。
- inline-suppress 边角修复：`scan-ignore-line` 现在严格只匹配同行，不再因为前一行有 `scan-ignore-line` 误抑制下一行；`scan-ignore: RULE` 仍支持上一行/同行（命名注释一般写在上方）。

**模板自检**：

- `samples/templates/dark-mode/theme-aware-page.ets` 与 `samples/templates/list/infinite-list.ets` 的硬编码中文示例改为 `$r('app.string.xxx')` —— 模板自身从此通过 AGC-RJ-014（"自家 recipe 不能被自家 lint 拒"）。
- 全 6 fixture（5 个 Bad + 1 个 Good）+ 4 个 sample template 全量回归通过。

详见本 CHANGELOG 同级条目「LCC 三轮实测反馈 · v0.6 修复」（v0.6 反馈未单独归档，全部内容已内联到本变更日志）。

## [0.2.0] - 2026-05-06

完整施工方案与决策记录见 [`PLAN.md`](docs/PLAN.md)。本版完成 P0+P1 全套：

- **PostToolUse 钩子** · Claude Code 每次 Edit/Write 自动跑 ArkTS 反模式扫描 + OHPM 包名校验，结果回喂 AI 上下文
- **`tools/install.sh`** · curl-pipeable 一行装到任意鸿蒙 app（默认 Claude Code + Codex；可加 Cursor / Copilot）
- **`tools/check-ohpm-deps.sh`** · 黑/白名单 + ohpm CLI 三层 OHPM 包名校验
- **`tools/run-linter.sh`** · 离线 hvigorw codeLinter wrapper（不依赖 DevEco GUI）
- **`tools/generate-ai-configs.sh`** · 真单源 fan-out：`.claude/skills/*/SKILL.md` → `.cursor/rules/harmonyos.mdc` + `.github/copilot-instructions.md`
- **`07-publishing/checklist-2026-rejection-top20.md`** · 提审 Top 20 拒因（带稳定 ID `AGC-RJ-001…020`）
- **`tools/hooks/test-fixtures/`** · 钩子回归 fixture
- **`.claude/skills/harmonyos-review/`** · 代码审查 skill + 60+ 编号规则 + 报告模板

## [0.1.0] - 2026-05-06

仓库雏形：

- 10 个主题目录（`00-getting-started/` ~ `09-quick-reference/`）+ `CLAUDE.md` + `AGENTS.md`
- 4 个 `.claude/skills/`（arkts-rules / state-management / build-debug / signing-publish）
- 5300+ 篇 OpenHarmony 官方文档镜像（用 `tools/bootstrap-upstream-docs.sh` 拉取）
- `.mcp.json` 接通 mcp-harmonyos
- LICENSE / CONTRIBUTING / .gitignore / GitHub Actions markdown lint
- 版本叙述校正（API 21 = 2025-11-25 首发 / API 22 = 2026-01-23 推送）
- ArkEval 数据驱动：「数组就地 mutation」提到 CLAUDE.md § 0.5 最高优先级

[Unreleased]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/compare/v0.4.5...HEAD
[0.4.5]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/releases/tag/v0.4.5
[0.4.4]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/releases/tag/v0.4.4
[0.4.3]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/releases/tag/v0.4.3
[0.4.2]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/releases/tag/v0.4.2
[0.4.1]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/releases/tag/v0.4.1
[0.4.0]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/releases/tag/v0.4.0
[0.3.0]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/releases/tag/v0.3.0
[0.2.0]: https://github.com/Octo-o-o-o/harmonyos-ai-workspace/releases/tag/v0.2.0

<!-- v0.1.0 没有 GitHub release（pre-tag 本地里程碑，详见顶部说明） -->
[0.1.0]: #010---2026-05-06
