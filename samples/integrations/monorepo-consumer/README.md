# Monorepo Consumer Integration

> **场景**：你的 HarmonyOS shell 是一个大 monorepo 的子目录（例如 `apps/harmonyos/`），不是项目根。OctoDesk / 其他多端工程套件都是这个形态。

DevSpace 的 `tools/install.sh` 默认假设"项目根 = HarmonyOS app 根"，把 CLAUDE.md / hook 等文件直接铺在根。在 monorepo 里这会污染顶层并和别的子项目冲突。

**更好的做法（推荐）**：DevSpace 不复制进 monorepo，monorepo 写一个**薄 wrapper**调用本机 DevSpace。这样 DevSpace 一次升级，所有下游消费者都受益。

## 三个文件搞定接入

monorepo 根目录加这 3 个文件（按下面模板）：

| 文件 | 作用 |
|------|------|
| `scripts/harmony-post-edit.sh` | Claude Code PostToolUse 入口；scope 到 harmony 子目录，delegate 到 DevSpace |
| `scripts/harmony-dev-cycle.sh` | dev-cycle 命令薄 wrapper，注入项目特定的 `--dir / --bundle / --ability` |
| `.claude/settings.json` 加 PostToolUse hook | 把 wrapper 挂到 Claude Code 上 |

外加在 harmony 子目录的 `.gitignore` 里追加 `.claude/.harmonyos-last-scan.txt`（hook 的扫描状态文件，每次 edit 都写）。

## 模板：`scripts/harmony-post-edit.sh`

见同目录的 [`harmony-post-edit.sh.template`](harmony-post-edit.sh.template)。改两处即可：

```bash
HARMONY_DIR="$REPO_ROOT/apps/harmonyos"   # 改成你的 harmony 子目录相对路径
```

## 模板：`scripts/harmony-dev-cycle.sh`

见同目录的 [`harmony-dev-cycle.sh.template`](harmony-dev-cycle.sh.template)。改三处：

```bash
HARMONY_DIR="$REPO_ROOT/apps/harmonyos"
BUNDLE="com.example.app"
ABILITY="EntryAbility"
```

## `.claude/settings.json` 片段

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          { "type": "command", "command": "bash $CLAUDE_PROJECT_DIR/scripts/harmony-post-edit.sh" }
        ]
      }
    ]
  }
}
```

## DevSpace 定位方式

wrapper 默认从 `$HOME/WorkSpace/HarmonyOS_DevSpace` 找。换路径用环境变量：

```bash
export HARMONYOS_DEVSPACE=/opt/HarmonyOS_DevSpace
```

适合 CI 场景（DevSpace 可能 clone 在别处）。

## 验证

接好后跑下面三步：

```bash
# 1. 编辑 harmony 子目录文件，应该触发扫描（看到 stderr 输出）
echo '{"tool_name":"Edit","tool_input":{"file_path":"apps/harmonyos/entry/src/main/ets/pages/Index.ets"}}' \
  | CLAUDE_PROJECT_DIR=$(pwd) bash scripts/harmony-post-edit.sh

# 2. 编辑非 harmony 文件，应该静默退出 0（不浪费 token）
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/index.ts"}}' \
  | CLAUDE_PROJECT_DIR=$(pwd) bash scripts/harmony-post-edit.sh
echo "exit=$?"   # 应该是 0

# 3. dev-cycle 透传
./scripts/harmony-dev-cycle.sh --help
```

## 副作用 / 成本须知

PostToolUse hook 把扫描结果（违规清单）作为 stderr 注入到 Claude Code 下一轮 AI 上下文。**这是 token 成本**：

- 干净文件：0 token 注入
- 命中 1-3 条 violation：~100-300 tokens
- 大文件（如 1500 行 + 50 条同规则违规，会触发 collapse）：~700-1000 tokens
- 单次扫描耗时：通常 < 100ms，DevSpace post-edit.sh 自带 10s timeout 兜底

每天 50 次 harmony edit ≈ ~10K-15K tokens 额外 input（Opus ~$0.15-0.25 / day at 2026-05 价位）。

**关掉 / 临时降噪**：

- 整段 PR 都是已知违规、不希望 hook 喧宾夺主：临时 `export HARMONYOS_HOOK_NONBLOCKING=1`（DevSpace post-edit.sh 自带的 escape hatch；只关阻塞，stderr 还是会写但 exit 0）
- 单文件不想被扫：临时 `// scan-ignore: RULE-ID` 或 `// scan-ignore-line`
- 完全不想接 hook：删除 `.claude/settings.json` 里的 PostToolUse 段即可，hook 不会自动恢复

**不希望接入的情况**：

- 你的 monorepo 已经有自己的 ArkTS lint pipeline / CI gate，并且和 DevSpace 规则有冲突 —— 此时不建议同时跑两套，会让 AI 收到矛盾信号
- 你只是临时 prototype 一两个 .ets 文件，不值得加 wrapper

## 参考实现

OctoDesk Mobile Companion (`apps/harmonyos/` 子目录在一个 multi-platform monorepo 里) 是本模式的最早实施者。结构：

- `scripts/harmony-post-edit.sh` — scope wrapper
- `scripts/harmony-dev-cycle.sh` — dev-cycle wrapper
- `apps/harmonyos/.gitignore` 加 `.claude/.harmonyos-last-scan.txt`
- 反哺约定写进顶层 CLAUDE.md：踩坑当场反哺回 DevSpace（新增 scan 规则 / 追加 best-practices / 加 sample）
