#!/usr/bin/env bash
# harmony-dev-cycle.sh
#
# Generic HarmonyOS NEXT build → install → launch → log cycle for AI agents
# (Claude Code / Codex / OpenClaw / etc.). Wraps DevEco Studio's bundled
# hvigorw + hdc so the loop can run entirely in a terminal — agents don't
# need to switch to the DevEco GUI to see errors.
#
# Why this exists: DevEco's "Run" button is a wrapper around `hvigorw
# assembleHap` + `hdc install` + `hdc shell aa start` + a hilog panel.
# All of those are CLI-accessible. Surfacing them lets AI agents close
# the edit → build → install → diagnose loop without GUI round-trips,
# which is the real productivity multiplier for AI-driven HarmonyOS work.
#
# Usage:
#   harmony-dev-cycle.sh quick-check        # lightweight ArkTS/OHPM scan, no DevEco required
#   harmony-dev-cycle.sh build-check        # ohpm install → codeLinter → build HAP
#   harmony-dev-cycle.sh device-check       # install → launch → grab finite hilog
#   harmony-dev-cycle.sh cycle-once         # build → install → launch → grab finite hilog
#   harmony-dev-cycle.sh cycle              # build → install → launch → tail hilog until Ctrl+C
#   harmony-dev-cycle.sh build              # compile + package HAP
#   harmony-dev-cycle.sh install            # install latest HAP to attached emulator/device
#   harmony-dev-cycle.sh run                # launch mainElement ability
#   harmony-dev-cycle.sh test [aa-args]     # build main+ohosTest HAPs → install → `aa test`
#                                           #   (Instrument Test on device; extra -s filters pass through;
#                                           #    test module defaults to <module>_test, override via TEST_MODULE env)
#   harmony-dev-cycle.sh logs [filter]      # tail hilog (with optional grep filter)
#   harmony-dev-cycle.sh logs-grab [secs]   # non-interactive: capture N seconds of hilog to /tmp
#   harmony-dev-cycle.sh devices            # list connected emulators/devices
#   harmony-dev-cycle.sh clean              # hvigor clean
#   harmony-dev-cycle.sh --help             # show this help
#
# All commands accept (in any position):
#   --dir <path>      project root (default: $HARMONY_PROJECT_DIR or current dir)
#   --bundle <id>     bundleName (default: auto-read from AppScope/app.json5)
#   --ability <name>  ability name (default: auto-read from entry/src/main/module.json5)
#   --module <name>   module name (default: entry)
#   --target <tgt>    hdc target (default: only target if exactly one connected)
#   --logs-secs <n>   seconds to capture for device-check / cycle-once (default: 8)
#
# Required env (with sensible auto-probe on macOS):
#   DEVECO_HOME       points at "/Applications/DevEco-Studio.app/Contents" (or your install)
#                     auto-probed on macOS; required on Linux / Windows
#   DEVECO_SDK_HOME   defaults to $DEVECO_HOME/sdk (hvigorw needs this)
#
# Prerequisites (GUI-only steps the CLI can't replicate):
#   1. Launch your HarmonyOS emulator from DevEco
#        (Tools → Device Manager → Local Emulator → Start)
#      hdc can talk to a running emulator but can't spawn the emulator process.
#   2. In DevEco, do one Auto-Sign pass:
#        File → Project Structure → Project → Signing Configs →
#        ✅ Automatically generate signature, log in Huawei account
#      This writes signing material into build-profile.json5 so subsequent
#      CLI builds can produce a signed HAP without the GUI.
#
# After that, AI agents can drive everything from terminal:
#
#   $ harmony-dev-cycle.sh build 2>&1 | tee /tmp/last-build.log
#   $ grep "ArkTS Compiler Error" /tmp/last-build.log    # find compile errors
#   ... AI fixes source ...
#   $ harmony-dev-cycle.sh cycle-once                     # build + install + run + finite logs
#   $ harmony-dev-cycle.sh logs-grab 5                    # snapshot 5s runtime log
#   $ harmony-dev-cycle.sh logs ArkTS                     # filter to ArkTS-tagged lines
#
# Installation:
#   - Run from HarmonyOS_DevSpace clone:
#       ~/WorkSpace/HarmonyOS_DevSpace/tools/harmony-dev-cycle.sh ...
#   - Or copy to your project (e.g. apps/harmonyos/dev-cycle.sh) and edit defaults.
#   - Or symlink into PATH:
#       ln -s ~/WorkSpace/HarmonyOS_DevSpace/tools/harmony-dev-cycle.sh ~/.local/bin/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------- arg parsing ----------
PROJECT_DIR=""
BUNDLE=""
ABILITY=""
MODULE_NAME="entry"
HDC_TARGET=""
LOG_SECS="8"

positional=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) PROJECT_DIR="$2"; shift 2 ;;
    --bundle) BUNDLE="$2"; shift 2 ;;
    --ability) ABILITY="$2"; shift 2 ;;
    --module) MODULE_NAME="$2"; shift 2 ;;
    --target) HDC_TARGET="$2"; shift 2 ;;
    --logs-secs) LOG_SECS="$2"; shift 2 ;;
    -h|--help) HELP=1; shift ;;
    *) positional+=("$1"); shift ;;
  esac
done

if [[ "${HELP:-0}" == "1" ]]; then
  awk '/^set -euo/{exit} NR>1' "$0" | sed 's/^# \?//'
  exit 0
fi

set -- "${positional[@]:-}"
cmd="${1:-cycle-once}"
shift || true

# ---------- project dir ----------
if [[ -z "$PROJECT_DIR" ]]; then
  PROJECT_DIR="${HARMONY_PROJECT_DIR:-$(pwd)}"
fi
if [[ ! -f "$PROJECT_DIR/AppScope/app.json5" ]]; then
  echo "ERROR: $PROJECT_DIR doesn't look like a HarmonyOS project root (no AppScope/app.json5)." >&2
  echo "       Pass --dir <path> or cd into the project root, or set HARMONY_PROJECT_DIR." >&2
  exit 1
fi
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# ---------- DevEco tooling auto-probe ----------
NEEDS_DEVECO="1"
case "$cmd" in
  quick-check) NEEDS_DEVECO="0" ;;
esac

HVIGORW=""
HDC=""
OHPM="${OHPM:-}"

if [[ "$NEEDS_DEVECO" == "1" && -z "${DEVECO_HOME:-}" ]]; then
  for candidate in \
    "/Applications/DevEco-Studio.app/Contents" \
    "$HOME/Applications/DevEco-Studio.app/Contents" \
    "/opt/deveco-studio" \
    "$HOME/deveco-studio"; do
    if [[ -d "$candidate/tools/hvigor/bin" ]]; then
      DEVECO_HOME="$candidate"
      break
    fi
  done
fi
if [[ "$NEEDS_DEVECO" == "1" && -z "${DEVECO_HOME:-}" ]]; then
  echo "ERROR: DEVECO_HOME not set and not auto-detected." >&2
  echo "       Set it to your DevEco Studio install (Contents/) directory, e.g.:" >&2
  echo "         export DEVECO_HOME=/Applications/DevEco-Studio.app/Contents" >&2
  exit 1
fi

if [[ "$NEEDS_DEVECO" == "1" ]]; then
  export DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-$DEVECO_HOME/sdk}"
  export NODE_HOME="${NODE_HOME:-$DEVECO_HOME/tools/node}"
  HVIGORW="$DEVECO_HOME/tools/hvigor/bin/hvigorw"
  HDC="$DEVECO_SDK_HOME/default/openharmony/toolchains/hdc"
  [[ -x "$HVIGORW" ]] || { echo "ERROR: hvigorw not found at $HVIGORW" >&2; exit 1; }
  [[ -x "$HDC" ]] || { echo "ERROR: hdc not found at $HDC" >&2; exit 1; }

  if [[ -z "$OHPM" ]]; then
    if command -v ohpm >/dev/null 2>&1; then
      OHPM="$(command -v ohpm)"
    elif [[ -x "$DEVECO_HOME/tools/ohpm/bin/ohpm" ]]; then
      OHPM="$DEVECO_HOME/tools/ohpm/bin/ohpm"
    fi
  fi
fi

# ---------- auto-detect bundle / ability ----------
if [[ -z "$BUNDLE" ]]; then
  BUNDLE=$(grep -E '"bundleName"' "$PROJECT_DIR/AppScope/app.json5" \
    | head -1 \
    | sed -E 's/.*"bundleName"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' || true)
fi
[[ -z "$BUNDLE" ]] && { echo "ERROR: couldn't auto-detect bundleName from AppScope/app.json5; pass --bundle <id>" >&2; exit 1; }

if [[ -z "$ABILITY" ]]; then
  MODULE_JSON="$PROJECT_DIR/$MODULE_NAME/src/main/module.json5"
  if [[ -f "$MODULE_JSON" ]]; then
    ABILITY=$(grep -E '"mainElement"' "$MODULE_JSON" \
      | head -1 \
      | sed -E 's/.*"mainElement"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' || true)
  fi
  ABILITY="${ABILITY:-EntryAbility}"
fi

# ---------- hdc target helper ----------
hdc_with_target() {
  if [[ -n "$HDC_TARGET" ]]; then
    "$HDC" -t "$HDC_TARGET" "$@"
  else
    "$HDC" "$@"
  fi
}

# ---------- command implementations ----------
do_quick_check() {
  local scan_script="$SCRIPT_DIR/hooks/lib/scan-arkts.sh"
  local ohpm_script="$SCRIPT_DIR/check-ohpm-deps.sh"
  local worst=0
  local files=""
  local f rc

  [[ -f "$scan_script" ]] || { echo "ERROR: scan-arkts.sh not found at $scan_script" >&2; exit 1; }

  if [[ "$#" -gt 0 ]]; then
    files="$*"
  elif [[ -d "$PROJECT_DIR/$MODULE_NAME/src/main" ]]; then
    files=$(find "$PROJECT_DIR/$MODULE_NAME/src/main" -type f \( -name "*.ets" -o -name "*.ts" \) 2>/dev/null | sort)
  fi

  if [[ -n "$files" ]]; then
    for f in $files; do
      [[ -f "$f" ]] || continue
      rc=0
      bash "$scan_script" "$f" || rc=$?
      [[ "$rc" -gt "$worst" ]] && worst="$rc"
    done
  else
    echo ">>> no ArkTS/TS files found under $PROJECT_DIR/$MODULE_NAME/src/main"
  fi

  if [[ -f "$ohpm_script" ]]; then
    for f in "$PROJECT_DIR/oh-package.json5" "$PROJECT_DIR/$MODULE_NAME/oh-package.json5"; do
      [[ -f "$f" ]] || continue
      rc=0
      bash "$ohpm_script" "$f" || rc=$?
      [[ "$rc" -gt "$worst" ]] && worst="$rc"
    done
  fi

  return "$worst"
}

do_ohpm_install() {
  if [[ ! -f "$PROJECT_DIR/oh-package.json5" && ! -f "$PROJECT_DIR/$MODULE_NAME/oh-package.json5" ]]; then
    echo ">>> no oh-package.json5 found, skipping ohpm install"
    return 0
  fi
  if [[ -z "$OHPM" ]]; then
    echo "WARN: ohpm not found; skipping dependency install" >&2
    return 0
  fi

  if [[ -f "$PROJECT_DIR/oh-package.json5" ]]; then
    cd "$PROJECT_DIR"
  else
    cd "$PROJECT_DIR/$MODULE_NAME"
  fi
  echo ">>> running ohpm install"
  "$OHPM" install
}

do_code_linter() {
  cd "$PROJECT_DIR"
  echo ">>> running hvigorw codeLinter"
  "$HVIGORW" codeLinter --no-daemon
}

do_build() {
  cd "$PROJECT_DIR"
  "$HVIGORW" --mode module \
    -p module="$MODULE_NAME"@default \
    -p product=default \
    -p buildMode=debug \
    assembleHap --no-daemon "$@"
}

do_build_check() {
  local rc=0
  do_quick_check || rc=$?
  if [[ "$rc" -ge 2 ]]; then
    echo "ERROR: quick-check found High severity issues; build-check stopped." >&2
    exit "$rc"
  fi
  do_ohpm_install
  do_code_linter
  do_build "$@"
}

do_clean() {
  cd "$PROJECT_DIR"
  "$HVIGORW" --mode module \
    -p module="$MODULE_NAME"@default \
    -p product=default \
    clean --no-daemon
}

find_hap() {
  # $1: outputs 子目录（default = 主 HAP；ohosTest = 测试 HAP），缺省 default。
  # 限定子目录很重要：跑过 test 子命令后 build/ 下同时存在 default 与 ohosTest 两套产物，
  # 不限定会把 ohosTest HAP 误当主 HAP 装上去。优先取签名产物，同名多产物取排序最新。
  local sub="${1:-default}" signed
  signed=$(find "$PROJECT_DIR/$MODULE_NAME/build" -path "*outputs/$sub/*-signed.hap" -type f 2>/dev/null | sort | tail -1 || true)
  if [[ -n "$signed" ]]; then
    echo "$signed"
  else
    find "$PROJECT_DIR/$MODULE_NAME/build" -path "*outputs/$sub/*.hap" -type f 2>/dev/null | sort | tail -1 || true
  fi
}

do_install() {
  local HAP
  HAP=$(find_hap)
  if [[ -z "$HAP" ]]; then
    echo "ERROR: no .hap found under $PROJECT_DIR/$MODULE_NAME/build/. Run 'build' first." >&2
    exit 1
  fi
  echo ">>> installing $HAP"
  hdc_with_target install -r "$HAP"
}

do_run() {
  echo ">>> launching bundle=$BUNDLE ability=$ABILITY"
  hdc_with_target shell aa start -a "$ABILITY" -b "$BUNDLE"
}

do_clear_logs() {
  hdc_with_target shell hilog -r >/dev/null 2>&1 || true
}

do_logs() {
  if [[ "$#" -gt 0 ]]; then
    hdc_with_target hilog | grep -E --line-buffered "$@"
  else
    hdc_with_target hilog
  fi
}

do_logs_grab() {
  local secs="${1:-5}"
  local out
  out="/tmp/hilog-${BUNDLE}-$(date +%s).log"
  echo ">>> grabbing ${secs}s of hilog → $out"
  local pid_file="/tmp/.hdc-hilog.$$.pid"
  ( hdc_with_target hilog > "$out" 2>&1 & echo $! > "$pid_file" )
  sleep "$secs"
  kill "$(cat "$pid_file")" 2>/dev/null || true
  rm -f "$pid_file"
  echo "captured $(wc -l < "$out") lines"
  echo "tail:"
  tail -20 "$out"
}

do_devices() {
  echo ">>> hdc list targets:"
  "$HDC" list targets
}

do_device_check() {
  local secs="${1:-$LOG_SECS}"
  do_install
  do_clear_logs
  do_run
  do_logs_grab "$secs"
}

do_cycle_once() {
  local secs="${1:-$LOG_SECS}"
  do_build
  do_install
  do_clear_logs
  do_run
  do_logs_grab "$secs"
}

do_cycle() {
  do_build
  do_install
  do_run
  echo "--- streaming hilog (Ctrl+C to stop) ---"
  do_logs
}

do_test() {
  # Instrument Test（ohosTest）设备路线：
  #   构建主 HAP + ohosTest HAP（buildMode=test，hvigor 内置的测试编译模式）
  #   → 安装两个 HAP → hdc shell aa test 触发 OpenHarmonyTestRunner。
  # Local 单元测试（src/test/）没有官方 CLI 记载，建议 DevEco GUI 跑。
  # 额外的 aa test 过滤参数原样透传，如：test -s class LoginUiTest
  local test_module="${TEST_MODULE:-${MODULE_NAME}_test}"

  cd "$PROJECT_DIR"
  echo ">>> building main HAP (buildMode=test)"
  "$HVIGORW" --mode module \
    -p module="$MODULE_NAME"@default \
    -p product=default \
    -p buildMode=test \
    assembleHap --no-daemon
  echo ">>> building ohosTest HAP"
  "$HVIGORW" --mode module \
    -p module="$MODULE_NAME"@ohosTest \
    -p buildMode=test \
    assembleHap --no-daemon

  local MAIN_HAP TEST_HAP
  MAIN_HAP=$(find_hap default)
  TEST_HAP=$(find_hap ohosTest)
  [[ -z "$MAIN_HAP" ]] && { echo "ERROR: main HAP not found under $MODULE_NAME/build/**/outputs/default/" >&2; exit 1; }
  [[ -z "$TEST_HAP" ]] && { echo "ERROR: ohosTest HAP not found under $MODULE_NAME/build/**/outputs/ohosTest/（检查 ohosTest 签名配置，未签名会构建失败）" >&2; exit 1; }

  echo ">>> installing $MAIN_HAP"
  hdc_with_target install -r "$MAIN_HAP"
  echo ">>> installing $TEST_HAP"
  hdc_with_target install -r "$TEST_HAP"

  echo ">>> running: aa test -b $BUNDLE -m $test_module -s unittest OpenHarmonyTestRunner $*"
  local out rc=0
  out=$(hdc_with_target shell aa test -b "$BUNDLE" -m "$test_module" -s unittest OpenHarmonyTestRunner -s timeout 15000 "$@" 2>&1) || rc=$?
  printf '%s\n' "$out"
  echo "--- summary ---"
  printf '%s\n' "$out" | grep -E "OHOS_REPORT_(RESULT|CODE|STATUS: taskconsuming)" | tail -10 || true

  # 官方判定口径（unittest-guidelines）：
  #   OHOS_REPORT_RESULT: stream=Tests run: N, Failure: F, Error: E, Pass: P, Ignore: I
  # 通过 = RESULT 行存在 且 Failure=0 且 Error=0 且 aa test 退出码为 0。
  # 注意不能对全文 grep "Failure"——成功输出也固定含 "Failure: 0" 字样。
  local result_line failures errors
  result_line=$(printf '%s\n' "$out" | grep -E "OHOS_REPORT_RESULT: stream=Tests run:" | tail -1 || true)
  if [[ -z "$result_line" ]]; then
    echo "RESULT: EXECUTION ERROR — 未收到 OHOS_REPORT_RESULT（runner 未启动？检查设备连接 / ohosTest 签名 / -m 模块名，aa rc=$rc）"
    return 1
  fi
  failures=$(printf '%s' "$result_line" | sed -E 's/.*Failure: ([0-9]+).*/\1/')
  errors=$(printf '%s' "$result_line" | sed -E 's/.*Error: ([0-9]+).*/\1/')
  if [[ "$failures" == "0" && "$errors" == "0" && "$rc" == "0" ]]; then
    echo "RESULT: PASSED（$result_line）"
    return 0
  fi
  echo "RESULT: FAILED（Failure=$failures Error=$errors, aa rc=$rc；详情见上方输出）"
  return 1
}

# ---------- dispatch ----------
case "$cmd" in
  quick-check) do_quick_check "$@" ;;
  build-check) do_build_check "$@" ;;
  device-check) do_device_check "$@" ;;
  cycle-once) do_cycle_once "$@" ;;
  build) do_build "$@" ;;
  install) do_install ;;
  run) do_run ;;
  test) do_test "$@" ;;
  logs) do_logs "$@" ;;
  logs-grab) do_logs_grab "$@" ;;
  devices) do_devices ;;
  clean) do_clean ;;
  cycle) do_cycle ;;
  *) echo "usage: $0 {quick-check|build-check|device-check|cycle-once|build|install|run|test [aa-test-args]|logs [filter]|logs-grab [secs]|devices|clean|cycle} [--dir <path>] [--bundle <id>] [--ability <name>] [--module <name>] [--target <tgt>] [--logs-secs <n>]" >&2; exit 1 ;;
esac
