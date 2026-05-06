# 鸿蒙官方规范汇总（审查时引用）

> 这份文档把审查 checklist 中常被问到的官方规范源头列出来，方便 AI 在报告中给出权威引用。

## 1. ArkTS 语言规范

- 编码风格：`upstream-docs/openharmony-docs/zh-cn/application-dev/quick-start/arkts-coding-style-guide.md`
- TS → ArkTS 迁移：`upstream-docs/.../quick-start/arkts-migration-background.md`
- 高性能编程：`upstream-docs/.../quick-start/arkts-high-performance-programming.md`
- 官方 Cookbook：<https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/typescript-to-arkts-migration-guide>

## 2. 状态管理

- V1 概览：`upstream-docs/.../ui/state-management/arkts-state-management-overview.md`
- V2 新版：`upstream-docs/.../ui/state-management/arkts-new-state-management.md`
- 性能优化：`upstream-docs/.../performance/state-management-performance-optimization.md`

## 3. 性能基线

- 启动优化：`upstream-docs/.../performance/improve-application-startup-and-response-time.md`
- 列表优化：`upstream-docs/.../performance/lazyforeach-optimization.md`
- 复用机制：`upstream-docs/.../performance/component-reusable.md`
- 渲染流水线：`upstream-docs/.../performance/reduce-redundant-events-when-sliding.md`

## 4. 安全

- 应用沙箱：`upstream-docs/.../file-management/app-sandbox-directory.md`
- 加密：`upstream-docs/.../security/cryptoFramework-overview.md`
- 网络安全：`upstream-docs/.../security/network-security.md`
- 权限管理：`upstream-docs/.../security/AccessToken/access-token-overview.md`

## 5. 隐私合规

- 隐私政策：<https://developer.huawei.com/consumer/cn/agconnect/help/privacy-policy/>
- 个人信息处理：`upstream-docs/.../security/personal-information-protection.md`

## 6. 生命周期

- UIAbility：`upstream-docs/.../application-models/uiability-lifecycle.md`
- ArkUI 组件：`upstream-docs/.../ui/state-management/arkts-page-custom-components-lifecycle.md`

## 7. 数据库

- Rdb：`upstream-docs/.../database/data-persistence-by-rdb-store.md`
- Preferences：`upstream-docs/.../database/data-persistence-by-preferences.md`
- 加密 Rdb：`upstream-docs/.../database/database-encryption.md`

## 8. Kit 使用

- 完整 Kit 列表：`03-platform-apis/README.md` § Kit 索引
- Network Kit：`upstream-docs/.../reference/apis-network-kit/`
- File Kit：`upstream-docs/.../reference/apis-core-file-kit/`
- Image Kit：`upstream-docs/.../reference/apis-image-kit/`

## 9. 上架审核

- AGC 审核标准：<https://developer.huawei.com/consumer/cn/doc/distribution/app/agc-help-checkdevelop-0000001146642468>
- 应用质量金奖标准：<https://developer.huawei.com/consumer/cn/doc/distribution/app/agc-help-app-quality-gold-0000001505871505>
- 隐私权限审核：<https://developer.huawei.com/consumer/cn/doc/distribution/app/50127>

## 10. 错误码

- HiLog：`upstream-docs/.../reference/apis-performance-analysis-kit/js-apis-hilog.md`
- BusinessError：`upstream-docs/.../reference/errorcode-universal.md`

---

## 引用约定

在审查报告中给出权威源时：

1. **优先本地**：`upstream-docs/.../specific-file.md` — AI 可直接读
2. **次选官网链接**：含具体锚点，例如 `https://developer.huawei.com/consumer/cn/doc/...#section-id`
3. **不要泛泛说"参考官方文档"** — 没有具体路径等于没引用
