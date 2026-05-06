# Recipe · LazyForEach 长列表 + 下拉刷新 + 上拉加载

> verified_against: harmonyos-6.0.2-api22 · last sync 2026-05-07
>
> 关联规则：`PERF-002`（长列表必须用 LazyForEach）、`STATE-002`（数组替换引用）

## 约束

1. **超过 50 项的列表必须用 `LazyForEach` + `IDataSource`**——`ForEach` 会一次性渲染所有项导致掉帧
2. **`IDataSource` 数据变更必须**通过 `notifyDataReload()` / `notifyDataAdd()` / `notifyDataChange()` 通知，**不要**直接改内部数组
3. **`Refresh` 组件**用于下拉刷新；上拉加载更多用 `List.onReachEnd()` 监听
4. **每个 list item 必须有稳定 key**（用 `LazyForEach(data, render, keyGen)` 第三参）

## 完整代码

见：

- [`item-data-source.ets`](item-data-source.ets) —— `IDataSource` 实现（含 add / replace / clear）
- [`infinite-list.ets`](infinite-list.ets) —— 完整列表组件（下拉刷新 + 上拉加载）

## 集成步骤

1. 复制两个 .ets 文件到 `entry/src/main/ets/components/`
2. 在你的页面里：

```typescript
import { InfiniteList } from '../components/infinite-list';

@Entry @Component struct Page {
  build() {
    InfiniteList({
      fetchPage: async (page: number) => {
        // 你的 API 调用
        return await api.fetchUsers(page);
      }
    })
  }
}
```

## 反模式

- ❌ 用 `ForEach(this.items, ...)` 渲染 1000 项 → 启动慢、掉帧
- ❌ `this.items.push(newItem)` → 不触发 LazyForEach 重渲染（需 `dataSource.add(newItem)`）
- ❌ 不传 keyGen → LazyForEach 用 index 当 key，列表中插入项时全部 rerender
- ❌ 在 `IDataSource.totalCount()` 里调 API → 频繁触发崩溃

## 进一步参考

- 官方文档：`upstream-docs/openharmony-docs/zh-cn/application-dev/ui/state-management/arkts-rendering-control-lazyforeach.md`
- 性能优化：`upstream-docs/.../performance/lazyforeach-optimization.md`
