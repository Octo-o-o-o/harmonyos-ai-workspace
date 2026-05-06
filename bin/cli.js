#!/usr/bin/env node
// harmonyos-ai-workspace · 薄 CLI 包装
// 把 tools/install.sh 的能力以 npx / npm i -g 的方式暴露
//
// 用法：
//   npx harmonyos-ai-workspace                              # 默认装到当前目录
//   npx harmonyos-ai-workspace --targets=claude,codex,cursor
//   npx harmonyos-ai-workspace --mirror=ghproxy
//   npx harmonyos-ai-workspace --uninstall
//
// 如果还没发到 npm，也可以直接用 GitHub source（无需先 publish）：
//   npx github:Octo-o-o-o/harmonyos-ai-workspace

'use strict';

const { spawnSync, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const REPO_OWNER = 'Octo-o-o-o';
const REPO_NAME = 'harmonyos-ai-workspace';
const REPO_BRANCH = 'main';

function log(msg) { process.stderr.write(`[harmonyos-ai-workspace] ${msg}\n`); }
function err(msg) { process.stderr.write(`\x1b[31m[✗]\x1b[0m ${msg}\n`); }

function platformOk() {
  const p = os.platform();
  if (p === 'darwin' || p === 'linux') return true;
  if (p === 'win32') {
    err('Windows native 暂不支持。请用 WSL2，或参考 docs/SETUP-FROM-SCRATCH.md');
    return false;
  }
  return true;
}

function findInstallScript() {
  // 路径 1：本地 git clone（开发场景）
  const local = path.resolve(__dirname, '..', 'tools', 'install.sh');
  if (fs.existsSync(local)) return { mode: 'local', path: local };

  // 路径 2：通过 npx 跑（npm 包模式）—— bin/cli.js 在 node_modules/harmonyos-ai-workspace/bin/
  // tools/install.sh 应该在同一包内
  return { mode: 'local', path: local };
}

function fetchAndExec(args) {
  const url = `https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}/tools/install.sh`;
  log(`fetching install.sh from ${url}`);

  // 先用 curl 拉到临时文件，再 bash 执行（避免 pipe 风险 + 日志清晰）
  const tmp = path.join(os.tmpdir(), `harmonyos-install-${Date.now()}.sh`);
  try {
    execSync(`curl -fsSL --max-time 30 "${url}" -o "${tmp}"`, { stdio: 'inherit' });
  } catch (e) {
    err('install.sh 下载失败。请检查网络或加 --mirror=ghproxy');
    process.exit(2);
  }

  const result = spawnSync('bash', [tmp, ...args], { stdio: 'inherit' });
  fs.unlinkSync(tmp);
  process.exit(result.status || 0);
}

function main() {
  if (!platformOk()) process.exit(2);

  const args = process.argv.slice(2);

  // 帮助
  if (args.includes('-h') || args.includes('--help')) {
    process.stdout.write(`
harmonyos-ai-workspace · npm CLI 包装

用法：
  npx harmonyos-ai-workspace                                   # 默认装 Claude Code + Codex
  npx harmonyos-ai-workspace --targets=claude,codex,cursor
  npx harmonyos-ai-workspace --mirror=ghproxy                  # 国内 GitHub 不通时
  npx harmonyos-ai-workspace --uninstall

也可以直接用 GitHub source（无需 npm publish）：
  npx -y github:${REPO_OWNER}/${REPO_NAME}

底层调用：tools/install.sh（参数透传）
完整文档：https://github.com/${REPO_OWNER}/${REPO_NAME}
`);
    process.exit(0);
  }

  // 优先用本地脚本（git clone 场景 / npm 包场景）
  const { mode, path: scriptPath } = findInstallScript();
  if (mode === 'local' && fs.existsSync(scriptPath)) {
    log(`using bundled install.sh: ${scriptPath}`);
    const result = spawnSync('bash', [scriptPath, ...args], { stdio: 'inherit' });
    process.exit(result.status || 0);
  }

  // 兜底：远程拉取（npx github: 用法在 npm < 10 时也走这条）
  fetchAndExec(args);
}

main();
