// 第四轮反馈回归 fixture（v0.7）：@CustomDialog 在 v0.6 装饰器名单缺失
// 期望命中：STATE-002（this.options.push）

@CustomDialog struct ConfirmDialog {
  controller?: CustomDialogController;
  options: string[] = [];

  addOption(o: string): void {
    this.options.push(o);   // ← 应报 STATE-002
  }

  build() {
    Column() { }
  }
}
