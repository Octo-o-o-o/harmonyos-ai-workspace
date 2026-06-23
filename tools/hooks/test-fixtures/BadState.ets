// Test fixture · 触发状态管理反模式
// 期望钩子命中：STATE-002, STATE-008, STATE-009

class TodoItem {
  id: number = 0;
  done: boolean = false;
}

@Entry
@Component
struct BadState {
  @State items: TodoItem[] = [];
  @State user: TodoItem = new TodoItem();
  @State selectedIds: Set<string> = new Set<string>();

  aboutToAppear(): void {
    // 模拟初始化
    this.items = [];
  }

  build() {
    // STATE-008: build() 内部不允许副作用
    console.info('rendering');                       // ARKTS-012 + STATE-008

    Column() {
      Button('add')
        .onClick(() => {
          // STATE-002: 数组就地 mutation 不会触发重渲染
          this.items.push({ id: 1, done: false } as TodoItem);
        })

      Button('toggle first')
        .onClick(() => {
          // STATE-003: 对象字段直改，类未 @Observed
          if (this.items.length > 0) {
            this.items[0].done = true;
          }
        })

      Button('rename user')
        .onClick(() => {
          // STATE-003: 对象字段直改
          this.user.id = 42;
        })

      Button('sort')
        .onClick(() => {
          // STATE-002: 就地 sort
          this.items.sort();
        })

      Button('select')
        .onClick(() => {
          // STATE-009: Set.add 就地 mutation 不触发重渲染
          this.selectedIds.add('todo-1');
        })
    }
  }
}
