# Samples

本目录用于演示性的**小型代码片段**与**起手模板**。

> 真业务 app 不要放这里——应放在仓库**同级目录**（如 `~/WorkSpace/apps/<your-app>/`），用 [`tools/install.sh`](../tools/install.sh) 把规则装到那个 app 项目，不要嵌进 DevSpace。理由见根目录 [`README.md`](../README.md)「推荐使用方式 A」。

## 当前状态

样例尚未提交。等社区 / 自用真鸿蒙 app 跑通后从中抽离骨架补到这里。

## 计划路线（按需实现，不强求全部完成）

| 名称 | 演示要点 |
| --- | --- |
| `hello-harmony` | 入口、`@Entry`、`@State`、`build()` |
| `http-todo` | `@kit.NetworkKit` 调 REST API |
| `preferences-notes` | 本地持久化（KV） |
| `image-gallery` | `LazyForEach` 长列表 |

> 钩子 / 扫描脚本的回归 fixture 不在这里——见 [`../tools/hooks/test-fixtures/`](../tools/hooks/test-fixtures/)。

## 创建一个 sample

1. 装好 DevEco Studio
2. **File → New → Create Project** → save 到 `samples/<name>/`
3. 详细见 [`../00-getting-started/03-first-project.md`](../00-getting-started/03-first-project.md)

代码片段速查见 [`../09-quick-reference/`](../09-quick-reference/)。
