# MCP 集成指引 · 两个 HarmonyOS MCP server 的接入对照

> 本仓库默认通过 `.mcp.json` 接入 [`mcp-harmonyos`](https://www.npmjs.com/package/mcp-harmonyos)（**只读**：查设备 / 项目 / 构建状态）。
>
> 如果你想要**动作型能力**——AI 直接 `hdc` 启动 app、点击屏幕、截图验证——本文档解释如何叠加接入第二个 MCP server。

---

## 两个候选 MCP server 对比

| 维度 | `mcp-harmonyos`（默认已接） | `XixianLiang/HarmonyOS-mcp-server` |
| --- | --- | --- |
| 类型 | 只读 | 动作型 |
| 工具数 | 7 个（device list / app info / build outputs 等） | 16 个（含 launch_app / click / long_click / swipe / input_text / get_uilayout / get_screenshot 等） |
| 实现 | npm（Node.js） | Python 3.13 + uv |
| 安装难度 | `npm install -g mcp-harmonyos` | clone + uv sync + 注册 MCP |
| 维护活跃度 | 持续更新 | **2025-04 后未更新**（v0.1.0，至今 1 年+） |
| 跟 Claude Code 接入 | 有官方说明 | 自己摸索（需写 MCP 配置） |
| 风险 | 低 | 中——半年未更新；`system_prompt.py` 是空文件；只支持 Python 3.13 |

---

## 决策建议

| 你的场景 | 建议 |
| --- | --- |
| 仅需 AI 写代码 + 钩子校验 + 查设备状态 | **保持现状**——`.mcp.json` 默认的 `mcp-harmonyos` 已够 |
| 想 AI "写 → 装 → 截图验证" 端到端闭环 | **叠加接入 G**（步骤见下） |
| 不想踩 G 的维护坑 | 用 `tools/hooks/examples/codex-precommit.sh` + 手动 `hdc install` |

**本仓库不直接 vendor G** 的代码——理由：

1. G 半年未更新，vendor 后维护责任落到本仓库
2. G 锁定 Python 3.13，跟本仓库纯 bash + Node 路线不一致
3. G 的 `system_prompt.py` 空文件、安装文档不全，需要二次开发

更稳的路线是**让感兴趣的用户按本指引自己 fork**。

---

## 接入步骤（叠加到现有 `.mcp.json`）

### 1. clone 并启动 G

```bash
cd ~/WorkSpace
git clone --depth=1 https://github.com/XixianLiang/HarmonyOS-mcp-server.git
cd HarmonyOS-mcp-server

# 检查 Python 版本
python3 --version       # 必须 3.13+
# 没有？用 pyenv：
#   pyenv install 3.13.0 && pyenv local 3.13.0

# 装依赖（uv 是个高效 venv 管理）
pip install uv
uv sync
```

### 2. 在你的鸿蒙 app 项目里加 MCP 配置

```json
{
  "mcpServers": {
    "harmonyos": {
      "command": "mcp-harmonyos",
      "args": [],
      "env": {}
    },
    "harmonyos-control": {
      "command": "uv",
      "args": ["--directory", "/Users/YOUR_NAME/WorkSpace/HarmonyOS-mcp-server", "run", "server.py"],
      "env": {}
    }
  }
}
```

> ⚠️ `--directory` 路径用**绝对路径**；MCP server 启动时不在 app 项目根。

### 3. 启动 Claude Code 验证

```bash
cd ~/WorkSpace/apps/my-app
claude
# > 列出当前连接的鸿蒙设备
# AI 会调 harmonyos.harmonyos_list_devices（mcp-harmonyos）
# > 帮我把这个 app 装到默认设备上跑起来
# AI 会调 harmonyos-control 的 launch_app
```

### 4. 端到端 demo（写 → 装 → 截图验证）

```
User: 帮我加一个 "Hello v2" 的 Text 组件，装到模拟器跑起来，截图给我看效果

AI 操作：
1. Edit entry/src/main/ets/pages/Index.ets    ← 钩子触发 ArkTS 校验
2. Bash hvigorw assembleHap -p buildMode=debug ← 真编译
3. mcp__harmonyos-control__launch_app          ← 启动 app
4. mcp__harmonyos-control__get_screenshot      ← 截图
5. 把截图返回给用户
```

**这是本仓库当前唯一缺的"端到端闭环"**。接入 G 之后填补。

---

## 已知坑

| 现象 | 原因 | 处置 |
| --- | --- | --- |
| `mcp-harmonyos-control` 启动失败：`No module named 'mcp'` | uv sync 没跑 | `cd HarmonyOS-mcp-server && uv sync` |
| `launch_app` 无响应 | 设备没连，或 `hdc list targets` 为空 | `hdc kill && hdc start; hdc list targets` |
| `get_screenshot` 文件路径错 | G 的 server.py 默认路径写死 | 看 `tools/hdc/screenshot.py` 改 `OUTPUT_DIR` |
| `system_prompt.py` 是空文件 | 上游 bug | 不影响功能；可自己补 prompt |

---

## 替代方案：不用 G，用 hdc + Bash

如果你不想引入 Python 依赖，可以让 AI 通过 Bash 工具**直接调** `hdc`：

```bash
hdc list targets
hdc -t <device-id> install -r entry/build/default/outputs/default/*.hap
hdc shell aa start -a EntryAbility -b com.example.x
hdc shell screencap -p /data/local/tmp/screen.png
hdc -t <device-id> file recv /data/local/tmp/screen.png ./screen.png
```

把这套封装到 `tools/hdc-helper.sh` 给 AI 调用，**等价于 G 的核心能力**，且无 Python 依赖。这是本仓库 v0.3 的候选项（PLAN.md P2-3）。

---

## 维护者注

如果 G 后续重新活跃（v0.2.0+ 发布、`system_prompt.py` 补全），考虑：

1. 把本指引升级为"默认接入 G"
2. 在 `tools/install.sh` 加 `--with-mcp-control` flag 自动配置

监测方法：每季度 review `https://github.com/XixianLiang/HarmonyOS-mcp-server/releases`。
