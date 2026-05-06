# HarmonyOS 设计语言

HarmonyOS 设计语言（HM Design）官方资料保存在：

- 在线版：<https://developer.huawei.com/consumer/cn/design/>（最新，含图、可下载组件库）
- 本地：`upstream-docs/openharmony-docs/zh-cn/design/`

## 1. 设计原则

| 原则 | 含义 |
| --- | --- |
| **一致** | 跨设备视觉、交互、信息架构一致 |
| **流畅** | 自然过渡、稳定 60fps |
| **聚焦** | 内容优先，弱化容器 |
| **包容** | 多设备、多文化、多用户群 |

## 2. 核心模块

| 模块 | 内容 | 本地参考 |
| --- | --- | --- |
| **HM Color** | 主题色、强调色、文本色、状态色 | `upstream-docs/zh-cn/design/ux-design/`（含图） |
| **HM Sans 字体** | 中文 / 英文 / 阿拉伯字族 | brew 已可装：`font-harmonyos-sans` |
| **图标** | 系统图标、应用图标规范 | 在线设计资源 |
| **栅格** | sm 4 / md 8 / lg 12 | `upstream-docs/.../ui/responsive-layout.md` |
| **间距** | 4 / 8 / 12 / 16 / 24 / 32 vp | |
| **动效** | 标准曲线、时长 200/300/400ms | `upstream-docs/.../ui/arkts-animation*.md` |
| **声音** | 系统提示音、触感反馈 | |

## 3. 字体（macOS 安装）

```bash
brew install --cask font-harmonyos-sans
brew install --cask font-harmonyos-sans-naskh-arabic
brew install --cask font-harmonyos-sans-sc            # 简体
brew install --cask font-harmonyos-sans-tc            # 繁体
```

安装后在 Figma / Sketch / IDE 都能使用。

## 4. 主题色 token

```typescript
// 系统色板（自动响应深浅色）
Text(...).fontColor($r('sys.color.ohos_id_color_primary'))
Text(...).fontColor($r('sys.color.ohos_id_color_secondary'))
Text(...).fontColor($r('sys.color.ohos_id_color_text_primary'))
Text(...).fontColor($r('sys.color.ohos_id_color_warning'))
Text(...).fontColor($r('sys.color.ohos_id_color_alert'))
```

完整 token 列表：`upstream-docs/.../reference/apis-arkui/arkui-ts/ts-system-resources.md`

## 5. 控件设计规则

- **按钮**：高度 36 / 40 / 56 vp 三档；圆角 50%
- **输入框**：高度 40 / 56 vp；圆角 8 vp
- **卡片**：圆角 12 vp，阴影按 elevation
- **导航栏**：高度 56 vp，标题居左
- **Tabs**：底部固定 4 项，超过 4 项用 Drawer

## 6. 多设备形态

| 形态 | 推荐布局 |
| --- | --- |
| Phone（< 600vp） | 单列，底部 Tab |
| Tablet（≥ 600vp） | 双栏（左导航 + 右内容） |
| Foldable（折叠中） | 自适应到内屏宽度 |
| PC 大屏 | 多栏 + 顶部菜单 |
| 车机 | 大字号 + 高对比 |

## 7. 在线资源

- 设计中心：<https://developer.huawei.com/consumer/cn/design/>
- 设计组件下载（Sketch / Figma）：<https://developer.huawei.com/consumer/cn/design/harmonyos-resource/>
- 图标库：<https://developer.huawei.com/consumer/cn/design/harmonyos-icon/>
- HM Sans 字体：<https://developer.huawei.com/consumer/cn/design/resource/>

## 8. 本地（已下载）

进入 `upstream-docs/openharmony-docs/zh-cn/design/ux-design/`，包含：

- 设计原则与栅格图（200+ 张 png）
- API 评审模板
- 系统组件设计规范

```bash
ls upstream-docs/openharmony-docs/zh-cn/design/ux-design/
```
