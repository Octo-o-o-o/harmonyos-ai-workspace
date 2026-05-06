#!/usr/bin/env bash
# codex-precommit.sh — Codex CLI / Cursor / 其他无 PostToolUse hook 工具的等价方案
#
# 安装方式：
#   ln -sf $PWD/tools/hooks/examples/codex-precommit.sh .git/hooks/pre-commit
#   或者 cp 到 .git/hooks/pre-commit 后 chmod +x
#
# 工作原理：
#   1. AI 写代码 → 用户 git add
#   2. 用户 git commit
#   3. 本脚本扫描 staged 文件，命中 High 级反模式则阻塞 commit
#   4. 用户看到 stderr 输出 → 改完再 commit；或临时跳过：GIT_NO_VERIFY=1 git commit
#
# 与 Claude Code 钩子的差异：
#   · Claude Code 钩子：AI Edit 完文件**立刻**回喂违规给 AI，AI 当场修
#   · 本 pre-commit 钩子：要等到 git commit 才校验，反馈链路更长
#   两者可以**同时存在**而不冲突——多一道防护

set -u

# 找到仓库根
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "[!] not in a git repo, skip" >&2
  exit 0
fi
cd "$REPO_ROOT"

# 找钩子脚本（容忍仓库结构差异）
SCAN_SCRIPT=""
for cand in \
  "tools/hooks/lib/scan-arkts.sh" \
  ".harmonyos-ai-workspace/tools/hooks/lib/scan-arkts.sh"
do
  [[ -f "$cand" ]] && SCAN_SCRIPT="$cand" && break
done

OHPM_SCRIPT=""
for cand in \
  "tools/check-ohpm-deps.sh" \
  ".harmonyos-ai-workspace/tools/check-ohpm-deps.sh"
do
  [[ -f "$cand" ]] && OHPM_SCRIPT="$cand" && break
done

if [[ -z "$SCAN_SCRIPT" && -z "$OHPM_SCRIPT" ]]; then
  echo "[!] harmonyos-ai-workspace 钩子脚本未找到，跳过" >&2
  exit 0
fi

# 仅扫本次 commit 改动的 .ets / .ts / oh-package.json5
files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ets|ts|json5)$' || true)
[[ -z "$files" ]] && exit 0

worst=0
for f in $files; do
  [[ ! -f "$f" ]] && continue
  case "$f" in
    *.ets|*.ts)
      [[ -n "$SCAN_SCRIPT" ]] && { bash "$SCAN_SCRIPT" "$f" || rc=$?; [[ "${rc:-0}" -gt $worst ]] && worst=$rc; }
      ;;
    */oh-package.json5|oh-package.json5)
      [[ -n "$OHPM_SCRIPT" ]] && { bash "$OHPM_SCRIPT" "$f" || rc=$?; [[ "${rc:-0}" -gt $worst ]] && worst=$rc; }
      ;;
  esac
done

if [[ "$worst" -ge 2 ]]; then
  echo "" >&2
  echo "[✗] commit 阻塞：存在 High 级反模式" >&2
  echo "    临时跳过：GIT_NO_VERIFY=1 git commit ..." >&2
  exit 1
fi

exit 0
