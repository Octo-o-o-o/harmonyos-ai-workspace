# Research Notes · 同类项目调研档案

> 完整调研已沉淀到 [`PLAN.md`](PLAN.md) § 五。本文件仅作"档案存根"，便于知道**调研发生过、什么时候做的、覆盖哪些项目**。

## 调研时间线

| 日期 | 范围 | 沉淀位置 |
| --- | --- | --- |
| 2026-05-06 一轮 | 4 家邻接项目（Awesome-HarmonyOS / DengShiyingA / yibaiba / CoreyLyn） + 命名可用性 | `PLAN.md` § 五 |
| 2026-05-06 二轮 | 8 家广搜（baidu-maps / cheliangzhao / ohosvscode / Phodal AutoDev / awesome-cursorrules issue #62 / hreyulog / sqlab / craftysecurity） | `PLAN.md` § 五 + § 六 |
| 2026-05-06 三轮 UX | 三家直接竞品深度对比（安装 / 日常使用 / 升级 / 贡献流） | `PLAN.md` § 三 / § 四 |

## 关键结论

1. 没有任何项目实现"PostToolUse 钩子 + curl 一行装 + Cursor/Copilot 同步 + 上游文档镜像"完整闭环
2. yibaiba/harmonyos-skills-pack 是 UX 上做得最完整的竞品，但默认装三目录污染严重（本仓库改为 Top 4 显式选择）
3. ArkEval 数据：Claude 4.5 Pass@1 仅 3.13%，给规则 + 钩子 + RAG 即可显著拉升

## 重新调研方式

竞品仓库已 clone 到 `/tmp/harmonyos-research/`。如要更新：

```bash
cd /tmp/harmonyos-research && rm -rf */
for r in DengShiyingA/harmonyos-ai-skill yibaiba/harmonyos-skills-pack CoreyLyn/harmonyos-skills; do
  git clone --depth=1 "https://github.com/$r.git"
done
```

## 维护节奏

每 3 个月 / HarmonyOS 大版本发布 / 听说有新竞品时复查一次，结果直接更新到 `PLAN.md`，不要在本文件累积内容。
