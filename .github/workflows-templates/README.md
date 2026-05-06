# Workflow 模板

由于初始推送时 OAuth token 缺 `workflow` scope，本仓库的 GitHub Actions 模板暂存在这里。

## 启用方式

```bash
# clone 后在本地执行：
mkdir -p .github/workflows
cp .github/workflows-templates/lint-md.yml.template .github/workflows/lint-md.yml

# 然后在仓库设置里给 push token 加 workflow scope，再 push：
gh auth refresh -s workflow
git add .github/workflows/lint-md.yml
git commit -m "ci: enable markdown lint workflow"
git push
```

## 内容

- `lint-md.yml.template` — markdown link check + markdownlint CI（PR 时跑）
- 配套 `markdown-link-check.json` 与 `markdownlint.json` 已在 `.github/` 下，不需要移动
