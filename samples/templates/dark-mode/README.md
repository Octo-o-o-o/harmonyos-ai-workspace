# Recipe · 深色模式（系统主题跟随 + 资源文件适配）

> verified_against: harmonyos-6.0.2-api22 · last sync 2026-05-07
>
> 关联规则：`AGC-RJ-016`（未适配深色模式 = 影响评分）

## 约束

1. **优先用系统色**：`$r('sys.color.ohos_id_color_text_primary')` 等会自动跟随系统主题，零代码切换
2. **自定义颜色用资源限定符**：`resources/dark/element/color.json` 自动覆盖 `resources/base/element/color.json`，系统进深色模式时切换
3. **`mediaquery` 监听**：仅在需要"代码层做不同行为"时用（如换图标），单纯换颜色不需要
4. **测试**：模拟器 / 真机 → **设置 → 显示与亮度 → 深色模式 切换**，看 UI 是否正确反转

## 完整代码

见 [`theme-aware-page.ets`](theme-aware-page.ets)。

## 集成步骤

### 1. 资源文件分浅 / 深两套

`entry/src/main/resources/base/element/color.json`（浅色，默认）：

```json
{
  "color": [
    { "name": "page_bg",     "value": "#FFFFFFFF" },
    { "name": "card_bg",     "value": "#FFF7F8FA" },
    { "name": "text_primary","value": "#FF1A1A1A" },
    { "name": "text_secondary","value": "#FF666666" },
    { "name": "brand",       "value": "#FF0A59F7" }
  ]
}
```

`entry/src/main/resources/dark/element/color.json`（深色，自动覆盖）：

```json
{
  "color": [
    { "name": "page_bg",     "value": "#FF1A1A1A" },
    { "name": "card_bg",     "value": "#FF2A2A2A" },
    { "name": "text_primary","value": "#FFEEEEEE" },
    { "name": "text_secondary","value": "#FFAAAAAA" },
    { "name": "brand",       "value": "#FF3D7DFF" }
  ]
}
```

### 2. UI 中只用 `$r('app.color.xxx')` 引用（不要写死十六进制）

```typescript
.backgroundColor($r('app.color.page_bg'))   // ✅ 自动跟随
.fontColor('#FFFFFF')                       // ❌ 永远白，深色模式下也白
```

### 3. 图标资源同样分两套

`resources/base/media/logo.png`（浅色 logo）vs `resources/dark/media/logo.png`（深色 logo）—— 文件名一致即可，系统自动选。

## 进阶：用 mediaquery 监听切换

仅当需要"代码层"响应主题变化（如打日志、上报）时：

见 `theme-aware-page.ets` 内的 `mediaquery.matchMediaSync('(dark-mode: true)')` 用法。

## 反模式

- ❌ UI 写死 `'#FFFFFF'` / `'#000000'` → 深色模式下看不见
- ❌ 自己实现"主题切换"按钮 → 应该跟随系统而非 app 内单独切
- ❌ 图标用单一资源 → 深色背景下浅色图标看不清

## 进一步参考

- 系统色完整列表：`upstream-docs/openharmony-docs/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-types.md`
- 资源限定符：`upstream-docs/.../quick-start/resource-categories-and-access.md`
