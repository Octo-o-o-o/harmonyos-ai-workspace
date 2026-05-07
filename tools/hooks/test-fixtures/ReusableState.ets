// 第四轮反馈回归 fixture（v0.7）：@Reusable 在 v0.6 装饰器名单缺失
// 期望命中：STATE-002（this.tags.push）—— 同行 @Reusable @Component struct

@Reusable @Component struct ListItem {
  @State tags: string[] = [];

  addTag(tag: string): void {
    this.tags.push(tag);   // ← 应报 STATE-002
  }

  build() {
    Row() { }
  }
}
