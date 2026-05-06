# Hook 配置示例（多 AI 工具）

> 本目录给**非 Claude Code 用户**提供等价的 hook 接入方式。
>
> Claude Code 用户什么都不用做——`.claude/settings.json` 已经配好。

钩子真正干活的脚本是统一的：[`tools/hooks/post-edit.sh`](../post-edit.sh)。本目录只是不同 AI 工具的"挂载方式"示例。

## 工具兼容性矩阵

| 工具 | 是否支持 PostToolUse 强校验 | 等价方案 | 示例文件 |
| --- | --- | --- | --- |
| **Claude Code** | ✅ 强校验（自动调用） | `.claude/settings.json` | 仓库根 `.claude/settings.json` 已配 |
| **Codex CLI** | ❌ 无 hook 机制 | git pre-commit + AGENTS.md 引导 | [`codex-precommit.sh`](codex-precommit.sh) |
| **Cursor** | ❌ 无 hook 机制（IDE 内嵌只支持 `.mdc` 规则） | git pre-commit + `.cursorrules` 引导 | [`codex-precommit.sh`](codex-precommit.sh)（同 Codex） |
| **GitHub Copilot Coding Agent** | ⚠️ Beta 阶段在探索 hook | git pre-commit + `.github/copilot-instructions.md` 引导 | [`copilot-coding-agent.json`](copilot-coding-agent.json) |
| **CI（GitHub Actions / GitLab CI）** | ✅ 等价校验 | 工作流调用 `--json` 模式 | [`github-action-arkts-check.yml`](github-action-arkts-check.yml) |

> **结论**：除了 Claude Code 是真正的 "AI Edit 后**强**校验"，其他工具最实际的等价物是 **git pre-commit + AGENTS.md/规则文件软引导**。这是工具能力差异，不是设计缺陷。

## 安装 git pre-commit（任何工具都可用）

```bash
# 在你的鸿蒙 app 项目根目录执行：
cat > .git/hooks/pre-commit <<'EOF'
#!/usr/bin/env bash
set -e
# 仅扫描本次 commit 改动的 .ets / .ts / .json5
files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ets|ts|json5)$' || true)
[ -z "$files" ] && exit 0

failed=0
for f in $files; do
  case "$f" in
    *.ets|*.ts)
      bash tools/hooks/lib/scan-arkts.sh "$f" || failed=$?
      ;;
    *oh-package.json5)
      bash tools/check-ohpm-deps.sh "$f" || failed=$?
      ;;
  esac
done

if [[ "$failed" -ge 2 ]]; then
  echo "存在 High 级反模式，commit 已阻塞。设置 GIT_NO_VERIFY=1 临时跳过。" >&2
  exit 1
fi
exit 0
EOF
chmod +x .git/hooks/pre-commit
```

之后任何 AI 工具（Codex / Cursor / Copilot）写完代码后，`git commit` 时自动校验。

## 各工具具体接入

详见示例文件中的注释。
