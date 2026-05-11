#!/usr/bin/env bash
# scaffold-deveco-project.sh
#
# 生成一个 DevEco Studio 6.1.x 可识别的 HarmonyOS NEXT 项目脚手架（API 12+）。
#
# 解决场景：你已经有一个 HarmonyOS 项目目录（含 AppScope/app.json5 + entry/src/）
# 但缺 DevEco 必需的脚手架文件（hvigorfile.ts、oh-package.json5、hvigor/、
# entry/build-profile.json5、code-linter.json5），导致 DevEco "Open Project"
# 不识别。本脚本一次性补齐 14 个脚手架文件。
#
# Usage:
#   ./scaffold-deveco-project.sh \
#     --bundle com.octoooo.desk \
#     --dir /path/to/your/harmonyos-project
#
# All flags:
#   --bundle <bundleName>     Bundle name, e.g. com.example.app (REQUIRED)
#   --dir <path>              Target directory (default: current dir)
#   --vendor <name>           Vendor field (default: same prefix as bundle)
#   --api-target <int>        Target API version in app.json5 (default: 22)
#   --api-min <int>           Min API version in app.json5 (default: 12)
#   --sdk-version <str>       DevEco SDK string for build-profile.json5
#                             (default: "6.1.1(24)")
#   --module-name <name>      Entry module name (default: entry)
#   --with-boilerplate        Also generate a hello-world EntryAbility + Index page
#                             (use only for brand-new projects with no ArkTS source)
#   --force                   Overwrite existing files (default: skip if exists)
#   -h, --help                Show this help
#
# Generated files (14):
#   hvigorfile.ts                       — root hvigor entrypoint
#   hvigor/hvigor-config.json5          — hvigor execution config
#   oh-package.json5                    — root OHPM package
#   code-linter.json5                   — ArkTS linter security rules
#   build-profile.json5                 — project build config (SDK / products)
#   .gitignore                          — HarmonyOS-specific git excludes
#   AppScope/app.json5                  — app-level config (bundle / vendor / API)
#   entry/.gitignore                    — entry-module excludes
#   entry/build-profile.json5           — entry-module build config
#   entry/hvigorfile.ts                 — entry-module hvigor entry
#   entry/oh-package.json5              — entry-module OHPM package
#
# Optional (with --with-boilerplate):
#   entry/src/main/module.json5         — entry module manifest
#   entry/src/main/ets/entryability/EntryAbility.ets
#   entry/src/main/ets/pages/Index.ets

set -euo pipefail

BUNDLE_NAME=""
TARGET_DIR="."
VENDOR=""
API_TARGET="22"
API_MIN="12"
SDK_VERSION="6.1.1(24)"
MODULE_NAME="entry"
WITH_BOILERPLATE=0
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle) BUNDLE_NAME="$2"; shift 2 ;;
    --dir) TARGET_DIR="$2"; shift 2 ;;
    --vendor) VENDOR="$2"; shift 2 ;;
    --api-target) API_TARGET="$2"; shift 2 ;;
    --api-min) API_MIN="$2"; shift 2 ;;
    --sdk-version) SDK_VERSION="$2"; shift 2 ;;
    --module-name) MODULE_NAME="$2"; shift 2 ;;
    --with-boilerplate) WITH_BOILERPLATE=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed 's/^#//' | head -n -1; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$BUNDLE_NAME" ]] && { echo "ERROR: --bundle is required" >&2; exit 1; }
[[ -z "$VENDOR" ]] && VENDOR=$(echo "$BUNDLE_NAME" | awk -F. '{print $2}')
[[ -z "$VENDOR" ]] && VENDOR="vendor"

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"
TARGET_ABS="$(pwd)"

written=0
skipped=0

emit() {
  # emit <relative-path>  (content from stdin)
  local rel="$1"
  if [[ -e "$rel" && "$FORCE" -ne 1 ]]; then
    echo "  · skip   $rel (exists; pass --force to overwrite)"
    skipped=$((skipped + 1))
    cat > /dev/null
    return
  fi
  mkdir -p "$(dirname "$rel")"
  cat > "$rel"
  echo "  ✓ wrote  $rel"
  written=$((written + 1))
}

echo "=== Scaffolding DevEco-compatible HarmonyOS NEXT project ==="
echo "  target dir:    $(pwd)"
echo "  bundle:        $BUNDLE_NAME"
echo "  vendor:        $VENDOR"
echo "  api (min/tgt): $API_MIN / $API_TARGET"
echo "  sdk string:    $SDK_VERSION"
echo "  module:        $MODULE_NAME"
echo "  boilerplate:   $WITH_BOILERPLATE (0=scaffold only, 1=also hello-world)"
echo

# ---------- root: hvigorfile.ts ----------
emit "hvigorfile.ts" <<'EOF'
import { appTasks } from '@ohos/hvigor-ohos-plugin';

export default {
  system: appTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []       /* Custom plugin to extend the functionality of Hvigor. */
}
EOF

# ---------- root: hvigor/hvigor-config.json5 ----------
emit "hvigor/hvigor-config.json5" <<EOF
{
  "modelVersion": "${SDK_VERSION%(*}",
  "dependencies": {
  },
  "execution": {
    // "analyze": "normal",                     /* Define the build analyze mode. Value: [ "normal" | "advanced" | "ultrafine" | false ]. Default: "normal" */
    // "daemon": true,                          /* Enable daemon compilation. Value: [ true | false ]. Default: true */
    // "incremental": true,                     /* Enable incremental compilation. Value: [ true | false ]. Default: true */
    // "parallel": true,                        /* Enable parallel compilation. Value: [ true | false ]. Default: true */
    // "typeCheck": false,                      /* Enable typeCheck. Value: [ true | false ]. Default: false */
    // "optimizationStrategy": "memory"         /* Define the optimization strategy. Value: [ "memory" | "performance" ]. Default: "memory" */
  },
  "logging": {
    // "level": "info"                          /* Define the log level. Value: [ "debug" | "info" | "warn" | "error" ]. Default: "info" */
  },
  "debugging": {
    // "stacktrace": false                      /* Disable stacktrace compilation. Value: [ true | false ]. Default: false */
  },
  "nodeOptions": {
    // "maxOldSpaceSize": 8192                  /* Enable nodeOptions maxOldSpaceSize compilation. Unit M. Used for the daemon process. Default: 8192*/
    // "exposeGC": true                         /* Enable to trigger garbage collection explicitly. Default: true*/
  }
}
EOF

# ---------- root: oh-package.json5 ----------
emit "oh-package.json5" <<EOF
{
  "modelVersion": "${SDK_VERSION%(*}",
  "description": "Please describe the basic information.",
  "dependencies": {
  },
  "devDependencies": {
    "@ohos/hypium": "1.0.25",
    "@ohos/hamock": "1.0.0"
  }
}
EOF

# ---------- root: build-profile.json5 ----------
emit "build-profile.json5" <<EOF
{
  "app": {
    "signingConfigs": [],
    "products": [
      {
        "name": "default",
        "signingConfig": "default",
        "targetSdkVersion": "${SDK_VERSION}",
        "compatibleSdkVersion": "${SDK_VERSION}",
        "runtimeOS": "HarmonyOS",
        "buildOption": {
          "strictMode": {
            "caseSensitiveCheck": true,
            "useNormalizedOHMUrl": true
          }
        }
      }
    ],
    "buildModeSet": [
      {
        "name": "debug",
      },
      {
        "name": "release"
      }
    ]
  },
  "modules": [
    {
      "name": "${MODULE_NAME}",
      "srcPath": "./${MODULE_NAME}",
      "targets": [
        {
          "name": "default",
          "applyToProducts": [
            "default"
          ]
        }
      ]
    }
  ]
}
EOF

# ---------- root: code-linter.json5 ----------
emit "code-linter.json5" <<'EOF'
{
  "files": [
    "**/*.ets"
  ],
  "ignore": [
    "**/src/ohosTest/**/*",
    "**/src/test/**/*",
    "**/src/mock/**/*",
    "**/node_modules/**/*",
    "**/oh_modules/**/*",
    "**/build/**/*",
    "**/.preview/**/*"
  ],
  "ruleSet": [
    "plugin:@performance/recommended",
    "plugin:@typescript-eslint/recommended"
  ],
  "rules": {
    "@security/no-unsafe-aes": "error",
    "@security/no-unsafe-hash": "error",
    "@security/no-unsafe-mac": "warn",
    "@security/no-unsafe-dh": "error",
    "@security/no-unsafe-dsa": "error",
    "@security/no-unsafe-ecdsa": "error",
    "@security/no-unsafe-rsa-encrypt": "error",
    "@security/no-unsafe-rsa-sign": "error",
    "@security/no-unsafe-rsa-key": "error",
    "@security/no-unsafe-dsa-key": "error",
    "@security/no-unsafe-dh-key": "error",
    "@security/no-unsafe-3des": "error"
  }
}
EOF

# ---------- root: .gitignore ----------
emit ".gitignore" <<'EOF'
/node_modules
/oh_modules
/local.properties
/.idea
**/build
/.hvigor
.cxx
/.clangd
/.clang-format
/.clang-tidy
**/.test
/.appanalyzer
EOF

# ---------- AppScope/app.json5 ----------
emit "AppScope/app.json5" <<EOF
{
  "app": {
    "bundleName": "${BUNDLE_NAME}",
    "vendor": "${VENDOR}",
    "versionCode": 1,
    "versionName": "0.0.0",
    "icon": "\$media:app_icon",
    "label": "\$string:app_name",
    "description": "\$string:app_description",
    "minAPIVersion": ${API_MIN},
    "targetAPIVersion": ${API_TARGET},
    "apiReleaseType": "Release"
  }
}
EOF

# ---------- entry/.gitignore ----------
emit "${MODULE_NAME}/.gitignore" <<'EOF'
/node_modules
/oh_modules
/.preview
/build
/.cxx
/.test
EOF

# ---------- entry/build-profile.json5 ----------
emit "${MODULE_NAME}/build-profile.json5" <<'EOF'
{
  "apiType": "stageMode",
  "buildOption": {
    "resOptions": {
      "copyCodeResource": {
        "enable": false
      }
    }
  },
  "buildOptionSet": [
    {
      "name": "release",
      "arkOptions": {
        "obfuscation": {
          "ruleOptions": {
            "enable": false,
            "files": [
              "./obfuscation-rules.txt"
            ]
          }
        }
      }
    },
  ],
  "targets": [
    {
      "name": "default"
    },
    {
      "name": "ohosTest"
    }
  ]
}
EOF

# ---------- entry/hvigorfile.ts ----------
emit "${MODULE_NAME}/hvigorfile.ts" <<'EOF'
import { hapTasks } from '@ohos/hvigor-ohos-plugin';

export default {
  system: hapTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []       /* Custom plugin to extend the functionality of Hvigor. */
}
EOF

# ---------- entry/oh-package.json5 ----------
emit "${MODULE_NAME}/oh-package.json5" <<EOF
{
  "name": "${MODULE_NAME}",
  "version": "1.0.0",
  "description": "Please describe the basic information.",
  "main": "",
  "author": "",
  "license": "",
  "dependencies": {}
}
EOF

# ---------- Boilerplate (only with --with-boilerplate) ----------
if [[ "$WITH_BOILERPLATE" -eq 1 ]]; then
  emit "${MODULE_NAME}/src/main/module.json5" <<EOF
{
  "module": {
    "name": "${MODULE_NAME}",
    "type": "entry",
    "description": "\$string:module_desc",
    "mainElement": "EntryAbility",
    "deviceTypes": [
      "phone",
      "tablet",
      "2in1"
    ],
    "deliveryWithInstall": true,
    "installationFree": false,
    "pages": "\$profile:main_pages",
    "abilities": [
      {
        "name": "EntryAbility",
        "srcEntry": "./ets/entryability/EntryAbility.ets",
        "description": "\$string:EntryAbility_desc",
        "icon": "\$media:layered_image",
        "label": "\$string:EntryAbility_label",
        "startWindowIcon": "\$media:startIcon",
        "startWindowBackground": "\$color:start_window_background",
        "exported": true,
        "skills": [
          {
            "entities": ["entity.system.home"],
            "actions": ["action.system.home"]
          }
        ]
      }
    ]
  }
}
EOF

  emit "${MODULE_NAME}/src/main/ets/entryability/EntryAbility.ets" <<'EOF'
import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
      }
    });
  }
}
EOF

  emit "${MODULE_NAME}/src/main/ets/pages/Index.ets" <<'EOF'
@Entry
@Component
struct Index {
  @State message: string = 'Hello, HarmonyOS!';

  build() {
    Row() {
      Column() {
        Text(this.message)
          .fontSize($r('app.float.page_text_font_size'))
          .fontWeight(FontWeight.Bold);
      }
      .width('100%');
    }
    .height('100%');
  }
}
EOF
fi

echo
echo "=== Done: wrote $written file(s), skipped $skipped ==="
echo
echo "Next steps:"
echo "  1. Open DevEco Studio → File → Open → select '${TARGET_ABS}'"
echo "  2. Let DevEco run 'sync' (downloads ohpm deps into .hvigor/ — auto-gitignored)"
echo "  3. If you want signing for sideload/release builds:"
echo "       File → Project Structure → Signing Configs → add your .p12 + .cer + .p7b"
echo "  4. Build a debug HAP:  hvigorw assembleHap -p product=default -p buildMode=debug"
