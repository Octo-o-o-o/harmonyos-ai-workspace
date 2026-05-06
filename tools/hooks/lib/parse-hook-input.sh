#!/usr/bin/env bash
# parse-hook-input.sh — 兼容多种 AI 助手的 hook stdin JSON
#
# 这个文件用 `source` 加载，它会把以下变量导出到调用方：
#   HOOK_TOOL_NAME    # 触发的工具名（Edit / Write / MultiEdit / 未知）
#   HOOK_FILE_PATH    # 被改动的文件绝对路径
#   HOOK_PROJECT_DIR  # 项目根目录（CLAUDE_PROJECT_DIR 优先；否则 git rev-parse；否则 PWD）
#   HOOK_RAW_INPUT    # 原始 stdin 内容（调试用）
#
# 兼容形态：
#   1. Claude Code: stdin 是 JSON，含 .tool_name / .tool_input.file_path
#   2. Codex / 自定义：可能传命令行 $1 = file_path
#   3. 手动调用：bash post-edit.sh path/to/file.ets

set -u

# 1) 项目根
HOOK_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-${CODEX_PROJECT_DIR:-}}"
if [[ -z "$HOOK_PROJECT_DIR" ]]; then
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    HOOK_PROJECT_DIR="$(git rev-parse --show-toplevel)"
  else
    HOOK_PROJECT_DIR="$PWD"
  fi
fi
export HOOK_PROJECT_DIR

# 2) 读取 stdin（如果不是 tty）
HOOK_RAW_INPUT=""
if [[ ! -t 0 ]]; then
  HOOK_RAW_INPUT="$(cat || true)"
fi
export HOOK_RAW_INPUT

# 3) 默认值
HOOK_TOOL_NAME="${HOOK_TOOL_NAME:-unknown}"
HOOK_FILE_PATH=""

# 4) 解析 JSON（jq 优先，否则用 grep/sed 兜底）
parse_with_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    return 1
  fi
  local tn fp
  tn="$(printf '%s' "$HOOK_RAW_INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
  fp="$(printf '%s' "$HOOK_RAW_INPUT" | jq -r '.tool_input.file_path // .tool_input.path // .file_path // empty' 2>/dev/null)"
  [[ -n "$tn" ]] && HOOK_TOOL_NAME="$tn"
  [[ -n "$fp" ]] && HOOK_FILE_PATH="$fp"
}

parse_with_sed() {
  # 简易 grep/sed 提取，用于没装 jq 的环境
  local tn fp
  tn="$(printf '%s' "$HOOK_RAW_INPUT" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  fp="$(printf '%s' "$HOOK_RAW_INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  [[ -z "$fp" ]] && fp="$(printf '%s' "$HOOK_RAW_INPUT" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  [[ -n "$tn" ]] && HOOK_TOOL_NAME="$tn"
  [[ -n "$fp" ]] && HOOK_FILE_PATH="$fp"
}

if [[ -n "$HOOK_RAW_INPUT" ]]; then
  parse_with_jq || parse_with_sed
fi

# 5) 命令行兜底（手动调用时）
if [[ -z "$HOOK_FILE_PATH" && $# -gt 0 ]]; then
  HOOK_FILE_PATH="$1"
fi

# 6) 路径规范化（相对 → 绝对，相对项目根）
if [[ -n "$HOOK_FILE_PATH" && "$HOOK_FILE_PATH" != /* ]]; then
  HOOK_FILE_PATH="$HOOK_PROJECT_DIR/$HOOK_FILE_PATH"
fi

export HOOK_TOOL_NAME HOOK_FILE_PATH

# 7) 调试模式
if [[ "${HOOK_DEBUG:-0}" == "1" ]]; then
  {
    echo "─── parse-hook-input ───"
    echo "  HOOK_PROJECT_DIR : $HOOK_PROJECT_DIR"
    echo "  HOOK_TOOL_NAME   : $HOOK_TOOL_NAME"
    echo "  HOOK_FILE_PATH   : $HOOK_FILE_PATH"
    echo "  HOOK_RAW_INPUT   : ${HOOK_RAW_INPUT:0:200}"
    echo "────────────────────────"
  } >&2
fi
