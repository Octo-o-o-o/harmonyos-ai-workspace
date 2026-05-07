# PrivateTalk · v0.4.2 真工程实测验收（2026-05-07）

> **里程碑**：本仓库的工具链首次以 npm 发布版（`harmonyos-ai-workspace@0.4.2`）形式进入一个真实在维护的鸿蒙 LLM 对话客户端工程（PrivateTalk）。所有 codex 第六轮评审针对的 install 安全性 / OHPM 网络误判 / V1V2 矛盾等问题，在真用户路径上跑通。
>
> 这份归档是给未来评审者看的"这版真的被用过、不是 demo"的证据。

## 测试矩阵

| 测试项 | 命令 | 结果 |
| --- | --- | --- |
| dry-run 预览 | `npx -y harmonyos-ai-workspace@0.4.2 --dry-run` | ✅ 列出 25 文件 + 1 manifest，不写盘 |
| 真安装 | `npx -y harmonyos-ai-workspace@0.4.2` | ✅ written 25, skipped 0（PrivateTalk 此前没 CLAUDE.md/AGENTS.md/.claude/） |
| 钩子触发反馈 | 编辑 Bad.ets `this.items.push(1)` | ✅ `[STATE-002 · High] ...` 正确反馈 |
| 全工程 scanner 扫 | `find -name '*.ets' -o -name '*.ts' | xargs scan` | ✅ 0 命中（与 LCC v0.6→v0.7 实测后的清洁状态一致） |
| build 不退化 | `hvigorw assembleHap` | ✅ BUILD SUCCESSFUL |
| OHPM 校验 | `bash tools/check-ohpm-deps.sh oh-package.json5` | ✅ exit=0 |
| 用户原文件保护 | check `PORT_ROADMAP.md` `RUNBOOK.md` | ✅ 完好保留 |
| 源码 0 改动 | `git status` PrivateTalk repo | ✅ 仅新增工具相关文件，源码未动 |

## 关键收益（评审者反馈原文）

### 1. 钩子在工程内自动触发，防止退化

> v0.6→v0.7 我们刚把 74 → 0 命中清干净——之前没钩子，AI 写新代码完全可能再涨回来；现在有钩子 = 0 命中能保住。后续 P1（TTS / Usage / 修改 PIN / Image Routing UI）每改一个文件都会被实时校验。

`.claude/settings.json` 注册的 PostToolUse hook 路径已正确加双引号（v0.4.0 P1-3 修复），含空格的路径也工作：

```json
{
  "matcher": "Write|Edit|MultiEdit",
  "hooks": [{
    "command": "bash \"$CLAUDE_PROJECT_DIR/tools/hooks/post-edit.sh\""
  }]
}
```

### 2. 工程从此自包含

> 之前：每次扫描都要写绝对路径 `bash ~/WorkSpace/HarmonyOS_DevSpace/tools/hooks/lib/scan-arkts.sh`
> 现在：`bash tools/hooks/lib/scan-arkts.sh` 就行。任何人 git clone PrivateTalk 后用 Claude Code 打开都立即获得 8 个 SKILL + .mcp.json + 完整工具链。

### 3. 装的 CLAUDE.md 比手写更新

> PrivateTalk 之前没 CLAUDE.md（M3-M12 期间引用的是 `~/WorkSpace/HarmonyOS_DevSpace/CLAUDE.md`）。v0.4.2 装的版本含：
> - 状态管理 V1/V2 不混用、替换引用铁律（M3-M12 反复用到）
> - runtime-pitfalls SKILL（含 Configuration import、HUKS、模块改名——这些都是我们踩过的坑）
> - inline-suppress 文档（PrivateTalk 现有 42 处 scan-ignore 注释的合法性背书）

### 4. AGENTS.md 让其他工具也能上手

> 如果以后有协作者用 Codex CLI / Cursor / Aider，直接读 AGENTS.md 就有完整鸿蒙规则。

## 次要观察

- 工程根新增 25 文件 + 1 manifest（`.harmonyos-ai-workspace.manifest` 含 sha256，uninstall 时只删本工具写的）
- 不冲突任何现有源码 / 文档
- build 时间无影响
- scanner 结果与离线扫描一致

## 没有负面影响

- ✅ PORT_ROADMAP / RUNBOOK 保留
- ✅ 编译产物一致
- ✅ scanner 结果一致
- ✅ build 时间无影响

## 评审里程碑

PrivateTalk 实测验收意味着：

1. **install 安全 promises 兑现**——v0.4.0 引入的 manifest + sha256 在真工程上验证有效；用户原 PORT_ROADMAP / RUNBOOK 完整保留
2. **钩子在 macOS 真环境工作**——`bash "$CLAUDE_PROJECT_DIR/..."` 双引号 quoting（v0.4.0 P1-3 修）让含空格的项目路径也能跑
3. **0 假阳率保持**——v0.6→v0.7 evolved 出来的装饰器上下文检测、PERF-002 启发式、collapse 等改进，让 scanner 在一个真实大型 LLM Chat 工程上达到 0 命中
4. **跨发版不退化**——v0.4.0/v0.4.1/v0.4.2 三连 patch 把 install/uninstall + npm 打包 + uninstall 残留全部修齐，真用户路径全过

后续 PrivateTalk 会作为本仓库工具链的"真世界对照基准"，每次 release 都在它上面回归一次。
