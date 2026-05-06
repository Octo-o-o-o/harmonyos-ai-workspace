// Recipe · LazyForEach 用的 IDataSource 标准实现
// verified_against: harmonyos-6.0.2-api22

export class ListDataSource<T> implements IDataSource {
  private items: T[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): T {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (!this.listeners.includes(listener)) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const idx = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }

  // ─── 改数据要走这些方法 · 不要直接 push items[] ────

  add(item: T): void {
    this.items.push(item);
    this.notifyDataAdd(this.items.length - 1);
  }

  addBatch(newItems: T[]): void {
    const start = this.items.length;
    this.items.push(...newItems);
    for (let i = 0; i < newItems.length; i++) {
      this.notifyDataAdd(start + i);
    }
  }

  replace(items: T[]): void {
    this.items = items;
    this.notifyDataReload();
  }

  clear(): void {
    this.items = [];
    this.notifyDataReload();
  }

  // ─── 通知 LazyForEach 刷新 ────────────────────────

  private notifyDataReload(): void {
    this.listeners.forEach(l => l.onDataReloaded());
  }

  private notifyDataAdd(index: number): void {
    this.listeners.forEach(l => l.onDataAdd(index));
  }

  private notifyDataChange(index: number): void {
    this.listeners.forEach(l => l.onDataChange(index));
  }
}
