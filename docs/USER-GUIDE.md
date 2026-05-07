# HarmonyOS AI Workspace · 使用说明书

> 装好之后怎么开始干活？这份文档是给装完工具想要立即上手的人，以及他的 AI 助手。
>
> **谁该读这份**：刚跑完 `npx -y harmonyos-ai-workspace` 的开发者；或者你想让 Claude / Codex / Cursor / Copilot 在已装好的项目里写鸿蒙代码。
>
> **太长不看版**：跑 `npx -y harmonyos-ai-workspace` → 启动 `claude` / `codex` / 打开 Cursor → 让 AI 写代码 → 钩子自动校验，违规直接反馈给 AI 自我修正。**就这样。**

---

## 目录

1. [首次使用：5 分钟验收](#1-首次使用5-分钟验收)
2. [第一次让 AI 改一个页面](#2-第一次让-ai-改一个页面)
3. [日常工作流](#3-日常工作流)
4. [典型任务怎么做](#4-典型任务怎么做)
5. [AI 协作的"魔法咒语"](#5-ai-协作的魔法咒语)
6. [故障排查](#6-故障排查)
7. [团队协作 / CI](#7-团队协作--ci)
8. [升级与卸载](#8-升级与卸载)

---

## 1. 首次使用：5 分钟验收

刚跑完 `npx -y harmonyos-ai-workspace` ？跑这 3 个命令验收装对了：

### 1.1 验收命令

```bash
# A. 看 manifest 知道工具写了哪些文件（你的 CLAUDE.md / AGENTS.md 如果之前有，会显示 skipped）
cat .harmonyos-ai-workspace.manifest | head -10

# B. 模拟 AI 写一个反模式，看钩子是否抓住
mkdir -p /tmp/_hoaw_test && cat > /tmp/_hoaw_test/Bad.ets <<'EOF'
@Entry @Component struct X {
  @State items: number[] = [];
  build() { Button('+').onClick(() => { this.items.push(1) }) }
}
EOF
echo '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/_hoaw_test/Bad.ets"}}' | \
  bash tools/hooks/post-edit.sh
rm -rf /tmp/_hoaw_test

# C. 跑离线 codeLinter（DevEco 装好就有 hvigorw）
bash tools/run-linter.sh
```

### 1.2 看到这些 = 工作正常

| 命令 | 预期输出 |
| --- | --- |
| A | `written\tAGENTS.md\t<sha256>` 这种行，可能含 `skipped\tCLAUDE.md\tpre-existing`（如果你之前有 CLAUDE.md） |
| B | `[STATE-002 · High] /tmp/_hoaw_test/Bad.ets:3: this.items.push(1) ...` |
| C | `BUILD SUCCESSFUL` 或具体的 lint 报告 |

**任何一个 fail 跳到 § 6 故障排查**。

---

## 2. 第一次让 AI 改一个页面

最快的"看到效果"方式——让 AI 改一个真实页面。下面三种 AI 助手任选其一：

### 2.1 用 Claude Code

```bash
cd ~/WorkSpace/apps/my-harmony-app   # 你的鸿蒙 app 根目录
claude                                # 启动后 CLAUDE.md 自动加载
```

在 Claude Code 里粘这个 prompt：

```
我想加一个"清空所有消息"按钮到 entry/src/main/ets/pages/Index.ets。
要求：
1. 严格按 .claude/skills/state-management/SKILL.md 的"替换引用"铁律——不要 splice/push
2. 用 V1 装饰器（默认风格，跟现有代码一致）
3. 写完跑一下钩子自检
```

**Claude 会**：
- 先读 `.claude/skills/state-management/SKILL.md` 拿到铁律
- 写 `this.messages = []` 而不是 `this.messages.splice(0, this.messages.length)`
- 编辑文件后钩子自动跑，违规会被反馈
- 自己修正后给你最终 diff

### 2.2 用 Codex CLI

```bash
cd ~/WorkSpace/apps/my-harmony-app
codex                                 # AGENTS.md 自动加载（agents.md 标准）
```

同样的 prompt——Codex 读到 `AGENTS.md` 第 0 节 SKILL 触发索引，按需展开 `state-management` 部分。

### 2.3 用 Cursor / Copilot

打开 IDE，在 chat 里粘 prompt 即可——`.cursor/rules/harmonyos.mdc` / `.github/copilot-instructions.md` 是 install 时已生成（或者跑 `bash tools/generate-ai-configs.sh` 重新生成），AI 在编辑 `.ets` 时自动应用规则。

---

## 3. 日常工作流

### 3.1 跟 Claude Code 一起写代码（推荐路径）

Claude Code 是当前对本仓库支持最完整的 AI 助手——`CLAUDE.md` 自动加载 + PostToolUse 钩子强校验。

**典型一次对话**：

```
你: "在 ChatPage 里加一个滚动到底部的按钮"

Claude: [读 .claude/skills/state-management/SKILL.md]
        [读 ChatPage.ets 现有代码]
        [写 diff 含 Scroller.scrollEdge(Edge.Bottom)]
        [Edit 文件]

钩子自动跑：
  · scan-arkts.sh 检查反模式 → 0 命中
  · check-ohpm-deps.sh 检查 import → 不引新包
  · 写入 .claude/.harmonyos-last-scan.txt

Claude: "已加滚动按钮，钩子 0 命中。建议你跑：
         hvigorw assembleHap -p buildMode=debug
         真编译验证。"
```

**关键习惯**：
- 启动 Claude Code 前先看一眼 `cat .claude/.harmonyos-last-scan.txt`——如果非空，说明上次有违规没修
- 让 AI 引用稳定 ID（见 § 5）
- 编译失败时把原文贴给 AI 而不是描述（见 § 6.1）

### 3.2 跟 Codex CLI 一起写代码

Codex 走 `AGENTS.md` 标准——所有 24+ 兼容工具同样吃这套。差异：

| 能力 | Claude Code | Codex CLI |
| --- | --- | --- |
| 项目宪法自动加载 | ✅ `CLAUDE.md` | ✅ `AGENTS.md`（[agents.md](https://agents.md/) 标准）|
| 8 SKILL 按需触发 | ✅ frontmatter 自动激活 | ⚠️ 通过 `AGENTS.md` § 0 索引手动指引 |
| Edit 后钩子强校验 | ✅ PostToolUse 触发 | ❌ 自己跑 `bash tools/hooks/post-edit.sh` 或 git pre-commit |
| `.cursor/rules/` / `.github/copilot-instructions.md` 同源 | ✅ | ✅ |

Codex 用户建议：把钩子加到 git pre-commit，commit 前自动跑：

```bash
cat > .git/hooks/pre-commit <<'SH'
#!/bin/bash
for f in $(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.(ets|ts)$'); do
  bash tools/hooks/lib/scan-arkts.sh "$f" || exit 1
done
SH
chmod +x .git/hooks/pre-commit
```

参考实现：[`tools/hooks/examples/codex-precommit.sh`](../tools/hooks/examples/codex-precommit.sh)。

### 3.3 跟 Cursor / Copilot 一起写代码

`.cursor/rules/harmonyos.mdc` 在 `*.ets` / `*.ts` / `module.json5` / `oh-package.json5` 编辑时自动激活。`.github/copilot-instructions.md` 在仓库内全局应用。

两者都没钩子机制——靠规则文件软引导。建议把钩子加进 GitHub Actions（见 § 7.2）让 PR 时强校验。

### 3.4 不用 AI 助手，纯手写

也可以——本仓库的工具链单独可用：

```bash
# 写代码前
cat .claude/skills/arkts-rules/SKILL.md            # 严格规则速查
cat .claude/skills/state-management/SKILL.md       # V1/V2 选型

# 写代码后
bash tools/hooks/lib/scan-arkts.sh path/to/your.ets   # 反模式扫描
bash tools/run-linter.sh                              # 跑 hvigorw codeLinter
bash tools/check-ohpm-deps.sh oh-package.json5        # OHPM 包名校验
hvigorw assembleHap -p buildMode=debug                # 真编译
```

---

## 4. 典型任务怎么做

下面是真鸿蒙开发中最常见的几类任务，附"贴给 AI 的 prompt 模板"。

### 4.1 写一个新页面 / 组件

```
请在 entry/src/main/ets/pages/MyPage.ets 创建一个新页面，含：
- 标题文本 + 两个按钮（"刷新"、"清空"）
- 状态：messages: ChatMessage[]，用 V1 装饰器

约束（必须遵守）：
- 严格按 .claude/skills/arkts-rules/SKILL.md：禁 any/var/解构/索引签名/对象字面量无类型
- 严格按 .claude/skills/state-management/SKILL.md：状态变更替换引用
- import 走 @kit.* 命名空间
- 文案走 $r('app.string.xxx') 资源（不要硬编码中文，AGC-RJ-014）

写完跑 bash tools/hooks/lib/scan-arkts.sh entry/src/main/ets/pages/MyPage.ets 应 exit=0
```

### 4.2 加权限申请

参考模板：[`samples/templates/permission/`](../samples/templates/permission/)

```
请按 samples/templates/permission/permission-helper.ets 的范式给 ChatPage 加麦克风权限。
要求：
- 模板覆盖了"申请 → 用户拒绝兜底 → 用户授权"全流程
- module.json5 同步 declare ohos.permission.MICROPHONE
```

### 4.3 接 LLM API（OpenAI / Claude / Gemini Vision 类）

参考 SKILL：[`.claude/skills/multimodal-llm/SKILL.md`](../.claude/skills/multimodal-llm/SKILL.md) + Case Study [`docs/case-studies/llm-chat-app.md`](case-studies/llm-chat-app.md)

```
请按 .claude/skills/multimodal-llm/SKILL.md 实现 OpenAI Vision API 调用。

特别注意（这是 ArkTS 限制 + LLM 实战经验）：
- ArkTS 不支持 string|object[] union → ChatMessage 必须拆 contentText / contentParts 双字段
- SSE 流式：用 buffer 拼接，按 \n\n 分包，最后一包可能不完整要保留
- 用 @kit.NetworkKit 的 http，用完调 .destroy()
- 详见 docs/case-studies/llm-chat-app.md M5、M6、M9 节
```

### 4.4 长列表（消息 / 会话 / Feed）

参考模板：[`samples/templates/list/`](../samples/templates/list/) — `infinite-list.ets` + `item-data-source.ets`

```
请按 samples/templates/list/ 的范式给 ConversationListPage 实现：
- LazyForEach 替代 ForEach（数据源 ≥ 50 项）
- IDataSource 标准实现 + notifyDataChange()
- 下拉刷新 + 上拉加载更多

注意：不要在 LazyForEach 数据源类内用 @State（IDataSource 不是 ArkUI 组件）
钩子识别这点不报 STATE-002——因为有装饰器上下文检测。
```

### 4.5 接深色模式

参考模板：[`samples/templates/dark-mode/theme-aware-page.ets`](../samples/templates/dark-mode/theme-aware-page.ets)

```
请按 samples/templates/dark-mode/theme-aware-page.ets 给整个 app 接深色模式：
- 颜色全走 $r('app.color.xxx')，资源限定符 dark/ 提供深色版
- 文案全走 $r('app.string.xxx')
- 用 mediaquery 监听系统主题切换
- AGC 上架要求支持深色模式（AGC-RJ-006）
```

### 4.6 编译失败了，怎么把错误传给 AI 让它修

这是 vibe coding 的最大痛点——以下流程效率最高：

```bash
# 步骤 1: 复制 hvigorw 完整输出（macOS 直接进剪贴板）
hvigorw assembleHap -p buildMode=debug 2>&1 | tail -30 | pbcopy
```

把这段贴给 Claude / Codex，附**这一句**（关键）：

```
请按 .claude/skills/arkts-rules/references/spec-quick-ref.md 里的稳定 ID
找出违反的规则编号 + 给最小 diff，不要重写整个文件。
如错误码是 9568305 / 9568322 / 16000050 等，对照
.claude/skills/build-debug/SKILL.md 错误码表给出诊断。
```

AI 会查 `spec-quick-ref.md` 找到对应 `ARKTS-XXX` / `STATE-XXX` 给出精确改写。

### 4.7 scanner 报错了 / 觉得是误报

scanner 真误报极少（PrivateTalk 真工程实测假阳率 0%），但难免。两个逃生口：

**逃生口 1：inline-suppress**（已审过的特殊场景）

```typescript
// scan-ignore: STATE-009                  ← 上一行抑制
this.prefs.delete('cached-token');         ← KV API，非 ArkUI 状态

this.cache.set('k', 'v');  // scan-ignore: STATE-009     ← 行尾抑制也行
```

详见 [`.claude/skills/arkts-rules/SKILL.md` § 抑制 scanner 误报](../.claude/skills/arkts-rules/SKILL.md#抑制-scanner-误报inline-suppress)。

**逃生口 2：报告真误报**

如果是规则本身问题（例如某个 case 不该报但被报了）：开 GitHub issue，附 fixture 代码 + scanner 输出 + 期望输出。本仓库的 9 个 fixture 就是这么累积来的。

### 4.8 OHPM 包名告警怎么办

scanner 输出三类告警：

| 类型 | 含义 | 怎么办 |
| --- | --- | --- |
| `OHPM-FAKE · High` | 黑名单或 `ohpm view` 明确 not-found | 停手——这是 AI 编的假包名，去 https://ohpm.openharmony.cn/ 搜真名 |
| `OHPM-NET · Low` | registry 502/超时/网络错 | 不阻断；网通后重跑 `npm test` 自查 |
| `OHPM-UNKNOWN · Medium` | `ohpm view` 返回非零但既非 not-found 也非网络错 | 手动在 https://ohpm.openharmony.cn/ 搜确认 |

---

## 5. AI 协作的"魔法咒语"

让 AI 充分用本仓库的规则——下面这些 prompt 模式经实战验证最有效。

### 5.1 让 AI 引用稳定 ID（核心咒语）

❌ **不要**这样问：

```
为什么我的 UI 不刷新？
```

✅ **改成**这样：

```
为什么我的 UI 不刷新？请按 .claude/skills/state-management/SKILL.md 的
铁律检查我的代码，引用稳定 ID（STATE-XXX）说明问题。
```

为什么这样更好？AI 会去读 SKILL，引用 `STATE-002`（数组就地 mutation）这种**稳定编号**——而不是凭印象给一个看似对的解释。下次出现同类问题，你 grep `STATE-002` 就能找到所有相关讨论。

### 5.2 让 AI 跑钩子并读输出

```
请编辑 entry/src/main/ets/pages/Index.ets 加一个清空按钮。
编辑完后跑 bash tools/hooks/lib/scan-arkts.sh entry/src/main/ets/pages/Index.ets
如果有违规请改完再回我。
```

Claude Code 会自动这么做（PostToolUse 钩子），但 Codex / Cursor 用户**需要在 prompt 里明示**才会跑。

### 5.3 让 AI 读 case study

```
我在做 LLM 对话客户端，要实现 SSE 流式。
请先读 docs/case-studies/llm-chat-app.md M6 节，按那个范式写。
不要凭印象——case study 是真踩过的坑。
```

### 5.4 让 AI 自查 spec-quick-ref.md（规则反查）

```
hvigorw 报 ERROR: arkts-no-untyped-obj-literals。
请在 .claude/skills/arkts-rules/references/spec-quick-ref.md 找对应的稳定 ID
和正确写法，给我最小 diff。
```

### 5.5 让 AI 主动查 upstream-docs（不要凭训练数据）

```
我要用 preferences API 存用户配置。
请先 grep upstream-docs/openharmony-docs/zh-cn/application-dev/reference/ 找
对应 Kit 的最新签名，确认 API 现在的形态再写代码。不要凭训练数据。
```

如果你没拉 `upstream-docs`（默认不拉，~2.7 GB），改成"先在 https://developer.huawei.com/consumer/cn/ 搜对应 Kit 文档确认 API 签名"。

### 5.6 让 AI 读 last-scan 修历史违规

```
请读 .claude/.harmonyos-last-scan.txt——这是上次扫描的违规列表。
按违规编号一一修，给统一 diff。
```

### 5.7 启动新对话时的"开场白模板"

每次启动 Claude Code / Codex 处理鸿蒙任务，第一句可以是：

```
我在改鸿蒙工程 [项目名]。
本仓库装了 harmonyos-ai-workspace（CLAUDE.md / AGENTS.md / 8 SKILL）。
今天我想 [具体任务描述]。
请先确认你能看到 .claude/skills/manifest.json + CLAUDE.md，然后开始。
```

让 AI 一开始就 anchor 到项目宪法上。

---

## 6. 故障排查

### 6.1 钩子没反应（Edit `.ets` 没看到扫描输出）

```bash
cat .claude/settings.json                                          # 应含 PostToolUse + post-edit.sh 路径
echo '{"tool_name":"Edit","tool_input":{"file_path":"x.ets"}}' | \
  bash tools/hooks/post-edit.sh                                    # 直接跑钩子
HOOK_DEBUG=1 bash tools/hooks/post-edit.sh < /dev/null             # 开调试日志
chmod +x tools/hooks/post-edit.sh tools/hooks/lib/*.sh             # 修可执行位
# settings.json 改动需重启 Claude Code 才生效
```

### 6.2 manifest 不存在但你想 uninstall

`bash tools/install.sh --uninstall` 拒绝执行 = 安全保护（防误删用户原文件）。如果你确实是用本工具装的、但 manifest 被删了：

```bash
# 选项 A：重装一遍（写新 manifest），然后再 uninstall
npx -y harmonyos-ai-workspace --force
npx -y harmonyos-ai-workspace --uninstall

# 选项 B：手动删（你确定知道哪些文件是本工具装的）
rm -f CLAUDE.md AGENTS.md .mcp.json
rm -rf .claude/ .cursor/ .github/copilot-instructions.md tools/hooks/ tools/check-*.sh tools/run-linter.sh
```

### 6.3 scanner 报"不该报的"误报

先用 inline-suppress（§ 4.7）标记。如果觉得是规则本身问题，开 issue 附 fixture——本仓库的 9 fixture 就是这么累积的。

### 6.4 钩子在含空格的项目路径下不工作

v0.4.0 已修（hook 命令加了双引号），但如果你用的是 v0.3 之前装的——重装：

```bash
npx -y harmonyos-ai-workspace --force   # 强制覆盖 .claude/settings.json
```

### 6.5 OHPM CLI 不在 PATH

```bash
ls ~/Library/Huawei/Sdk/*/openharmony/toolchains/ohpm*
export PATH="$PATH:~/Library/Huawei/Sdk/HarmonyOS-NEXT-DB1/openharmony/toolchains/ohpm/bin"
echo 'export PATH="$PATH:..."' >> ~/.zshrc   # 永久加
```

### 6.6 hvigorw 找不到（终端跑而不是 IDE 内）

```bash
# 鸿蒙 6 hvigor 5 个必设环境变量：
cat >> ~/.zshrc <<'ENV'
export DEVECO_SDK_HOME=$HOME/Library/Huawei/Sdk
export PATH=$DEVECO_SDK_HOME/HarmonyOS-NEXT-DB1/openharmony/toolchains/ohpm/bin:$PATH
export PATH=$DEVECO_SDK_HOME/HarmonyOS-NEXT-DB1/openharmony/toolchains:$PATH
ENV
source ~/.zshrc
```

完整诊断：[`.claude/skills/build-debug/SKILL.md`](../.claude/skills/build-debug/SKILL.md) § 终端 hvigorw 环境变量。

### 6.7 "AI 给的代码看上去对，但运行时不刷新 / 报错"

90% 是状态管理问题。粘这条给 AI：

```
我刚才那段代码运行时 [具体现象]。
请按 .claude/skills/state-management/SKILL.md 的"第一铁律：替换引用"自查
我的代码——是不是哪里 push/splice/sort 直接改了原对象。
列出问题 + 改写后的最小 diff。
```

---

## 7. 团队协作 / CI

### 7.1 git 入库

`tools/install.sh` 写入的所有文件**应该入 git**——这样团队任何人 clone 都直接拥有规则：

```bash
git add CLAUDE.md AGENTS.md .mcp.json \
        .claude/settings.json .claude/skills/ \
        .cursor/ .github/copilot-instructions.md \
        tools/ \
        .harmonyos-ai-workspace.manifest
git commit -m "chore: install harmonyos-ai-workspace"
```

`.harmonyos-ai-workspace.manifest` 入 git 让卸载在团队任何机器上都安全可执行。

`.claude/.harmonyos-last-scan.txt` **不要入 git**（运行时产物）：

```bash
echo '.claude/.harmonyos-last-scan.txt' >> .gitignore
```

### 7.2 GitHub Actions 集成

加 `.github/workflows/arkts-check.yml`：

```yaml
name: ArkTS check
on: [pull_request, push]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run scan-arkts on changed files
        run: |
          for f in $(git diff --name-only origin/main...HEAD | grep -E '\.(ets|ts)$'); do
            bash tools/hooks/lib/scan-arkts.sh "$f"
          done
```

参考实现：[`tools/hooks/examples/github-action-arkts-check.yml`](../tools/hooks/examples/github-action-arkts-check.yml)

### 7.3 Codex / pre-commit 用户

把钩子加到 git pre-commit：

```bash
cat > .git/hooks/pre-commit <<'SH'
#!/bin/bash
for f in $(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.(ets|ts)$'); do
  bash tools/hooks/lib/scan-arkts.sh "$f" || { echo "❌ $f 违反 ArkTS 规则"; exit 1; }
done
SH
chmod +x .git/hooks/pre-commit
```

参考：[`tools/hooks/examples/codex-precommit.sh`](../tools/hooks/examples/codex-precommit.sh)

### 7.4 自定义规则

scanner 的所有规则都在 [`tools/hooks/lib/scan-arkts.sh`](../tools/hooks/lib/scan-arkts.sh) 内联——加新规则在末尾加 `emit_high "RULE-ID" "$ln" ...` 块即可。配套加 fixture 在 `tools/hooks/test-fixtures/`。

每加一条新规则：

1. 在 `scan-arkts.sh` 加 grep 模式 + emit_high/emit_med 调用
2. 在 `tools/hooks/test-fixtures/` 加 `BadXXX.ets` fixture（应触发 = exit=2）
3. 跑 `npm test` 确认通过
4. 同步更新 `.claude/skills/arkts-rules/references/spec-quick-ref.md` 加 ID 映射

---

## 8. 升级与卸载

### 8.1 升级

```bash
# 装最新版（manifest + sha256 安全：你改过的文件不会被覆盖）
npx -y harmonyos-ai-workspace@latest

# 强制接管所有文件（不保留你的修改）
npx -y harmonyos-ai-workspace@latest --force
```

新版改了什么？看 [CHANGELOG.md](../CHANGELOG.md) 顶部最新条目。

### 8.2 卸载（安全模式）

```bash
npx -y harmonyos-ai-workspace --uninstall
```

输出会告诉你：
- 已删除（本工具写入且未被改过）：N
- 保留（你已修改过）：M  ← 这些会因为 sha256 不匹配被保留
- 保留（install 时已存在跳过的）：K  ← 你的原 CLAUDE.md / AGENTS.md
- 跳过（manifest 列出但已不存在）：L

### 8.3 卸载（强制模式）

```bash
npx -y harmonyos-ai-workspace --uninstall --force
```

会删所有 manifest 标记为 written 的文件——包括你改过的。**慎用**。

### 8.4 反馈 / 升级提示

- 发现规则误报 / 缺规则：开 issue 附 fixture
- 发现 install / hook BUG：开 issue 附完整命令输出 + 你的 bash version (`bash --version`)
- 想加新 SKILL / 新 recipe template：欢迎 PR
- 完整 issue 模板：[`CONTRIBUTING.md`](../CONTRIBUTING.md)

---

## 太长不看的核心

1. **30 秒装**：`npx -y harmonyos-ai-workspace`
2. **5 分钟验**：跑 § 1.1 的 3 个命令，看到 `STATE-002 · High` = 工作正常
3. **日常用**：启动 `claude` / `codex` / Cursor → 让 AI 写代码 → 钩子自动校验
4. **AI prompt 加这句**："请引用 .claude/skills/.../SKILL.md 里的稳定 ID + 给最小 diff"
5. **编译失败**：把 `hvigorw` 完整输出贴给 AI，附 § 4.6 的指令
6. **不喜欢了**：`npx -y harmonyos-ai-workspace --uninstall`（manifest 安全模式，你的原文件不会被吃）

更深的进阶用法（多 app 共享规则、三层发布策略、与同类项目对比）见 [`docs/USAGE-GUIDE.md`](USAGE-GUIDE.md)。
