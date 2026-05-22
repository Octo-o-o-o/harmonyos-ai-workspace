#!/usr/bin/env bash
# setup-codex-mcp.sh — register mcp-harmonyos in the user's Codex config.
#
# Codex discovers project skills from .agents/skills, but MCP servers are read
# from the user's Codex config. Keep this as an explicit opt-in setup step.

set -u

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
err()  { printf "${RED}[✗]${NC} %s\n" "$*"; }
info() { printf "${BLUE}[i]${NC} %s\n" "$*"; }

if ! command -v codex >/dev/null 2>&1; then
  err "未检测到 Codex CLI"
  echo "安装后重试：brew install codex 或 npm i -g @openai/codex"
  exit 2
fi

MCP_LIST=$(codex mcp list 2>/dev/null || true)
if echo "$MCP_LIST" | grep -Eq '^harmonyos[[:space:]]'; then
  if echo "$MCP_LIST" | grep -Eq '^harmonyos[[:space:]].*mcp-harmonyos'; then
    ok "Codex MCP 已存在：harmonyos → mcp-harmonyos"
    exit 0
  fi
  warn "Codex MCP 名称 harmonyos 已存在，但不是 mcp-harmonyos"
  echo "如要替换，请手动执行："
  echo "  codex mcp remove harmonyos"
  echo "  codex mcp add harmonyos -- npx -y mcp-harmonyos@latest"
  exit 1
fi

info "写入 Codex 用户级 MCP 配置：harmonyos → npx -y mcp-harmonyos@latest"
if codex mcp add harmonyos -- npx -y mcp-harmonyos@latest; then
  ok "Codex MCP 配置完成"
  echo "验证：codex mcp list"
else
  err "Codex MCP 配置失败"
  echo "可手动执行：codex mcp add harmonyos -- npx -y mcp-harmonyos@latest"
  exit 1
fi
