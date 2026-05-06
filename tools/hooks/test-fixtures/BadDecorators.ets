// Test fixture · 触发装饰器混用与误用
// 期望钩子命中：STATE-001, STATE-006

@Component
struct ChildV1 {
  @Link value: number;                            // V1 Link

  build() {
    Button('+1')
      .onClick(() => { this.value++ });
  }
}

// STATE-001: V1（@Component）与 V2（@ComponentV2）在同一文件 → 编译期会报错
@ComponentV2
struct ChildV2 {
  @Param value: number = 0;

  build() {
    Text(`${this.value}`)
  }
}

@Entry
@Component
struct BadDecorators {
  @State counter: number = 0;

  build() {
    Column() {
      // STATE-006: V1 @Link 调用方应该传 $$counter，不是 counter
      ChildV1({ value: this.counter })

      ChildV2({ value: this.counter })
    }
  }
}
