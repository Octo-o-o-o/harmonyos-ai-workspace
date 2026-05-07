// 第四轮反馈回归 fixture（v0.7）：v0.6 awk 状态机漏识别同行装饰器 + struct
// 期望命中：STATE-002（this.items.push）

@Entry @Component struct Page {
  @State items: number[] = [];

  add(x: number): void {
    this.items.push(x);   // ← 应报 STATE-002
  }

  build() {
    Column() { }
  }
}
