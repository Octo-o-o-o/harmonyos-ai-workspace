# ArkUI 声明式 UI 框架

ArkUI 是 HarmonyOS / OpenHarmony 的官方声明式 UI 框架。基于 ArkTS，与 React / SwiftUI / Compose 在思想上类似，但有自己的语法风格。

## 1. 心智模型

```
@Entry @Component struct PageName {
  @State data: Type = initialValue;

  build() {
    Container() {
      // children with chained attributes
    }
    .containerAttr1()
    .containerAttr2()
  }
}
```

- **build() 函数描述 UI 结构**，必须是纯函数（同样状态产出同样 UI）
- 链式属性：`.fontSize(24).fontColor(Color.Red)`
- 状态变化触发局部重新执行 `build()`
- ArkUI 编译器会做依赖追踪，只重渲染变化的子树

## 2. 必读官方目录

| 主题 | 本地路径 |
| --- | --- |
| UI 总览 | `upstream-docs/openharmony-docs/zh-cn/application-dev/ui/` |
| 状态管理 | `upstream-docs/.../ui/state-management/` |
| 通用属性 | `upstream-docs/.../reference/apis-arkui/arkui-ts/ts-universal-attributes-*.md` |
| 基本组件 | `upstream-docs/.../reference/apis-arkui/arkui-ts/ts-basic-components-*.md` |
| 容器组件 | `upstream-docs/.../reference/apis-arkui/arkui-ts/ts-container-*.md` |
| 媒体组件 | `upstream-docs/.../reference/apis-arkui/arkui-ts/ts-media-components-*.md` |
| 动画 | `upstream-docs/.../ui/arkts-animation*.md` |
| 路由 / 导航 | `upstream-docs/.../ui/arkts-navigation*.md` |
| 自定义绘制 / Canvas | `upstream-docs/.../ui/arkts-graphics-*.md` |

## 3. 常用容器

| 组件 | 等价 |
| --- | --- |
| `Column` | flex column |
| `Row` | flex row |
| `Stack` | overlap (z) |
| `Flex` | 完整 flex 控制 |
| `Grid` / `GridItem` | grid |
| `List` / `ListItem` | 列表（支持懒加载、分组） |
| `Swiper` | 轮播 |
| `Tabs` / `TabContent` | 选项卡 |
| `Scroll` | 滚动容器 |
| `Navigation` / `NavDestination` | 导航 |

## 4. 常用基础组件

| 组件 | 用途 |
| --- | --- |
| `Text` | 文本 |
| `Button` | 按钮 |
| `Image` | 图片，支持 `$r('app.media.x')` `http://` `file://` `data:` |
| `TextInput` / `TextArea` | 输入 |
| `Toggle` | 开关 / 复选 |
| `Slider` | 滑动条 |
| `Progress` | 进度 |
| `Checkbox` / `Radio` | 选框 |
| `Search` | 搜索框 |
| `LoadingProgress` | 加载动画 |
| `Web` | 内嵌网页 |
| `XComponent` | 视频 / 自定义渲染（OpenGL / NAPI） |

## 5. 状态管理示例

### 父子单向

```typescript
@Component
struct Child {
  @Prop title: string = '';
  build() { Text(this.title); }
}

@Entry @Component
struct Parent {
  @State name: string = 'world';
  build() {
    Column() {
      Child({ title: this.name });
      Button('change').onClick(() => this.name = 'HarmonyOS');
    }
  }
}
```

### 双向

```typescript
@Component
struct Counter {
  @Link count: number;
  build() { Button(`+1 (${this.count})`).onClick(() => this.count++); }
}

@Entry @Component
struct App {
  @State n: number = 0;
  build() {
    Column() {
      Text(`n=${this.n}`);
      Counter({ count: $$this.n });   // 注意 $$
    }
  }
}
```

### 跨层级

```typescript
@Entry @Component
struct Root {
  @Provide theme: 'light' | 'dark' = 'light';
  build() {
    Column() {
      Layer1();
      Button('toggle').onClick(() => this.theme = this.theme === 'light' ? 'dark' : 'light');
    }
  }
}

@Component
struct DeepChild {
  @Consume theme: 'light' | 'dark';
  build() { Text(`current: ${this.theme}`); }
}
```

### 监听派生

```typescript
@State items: number[] = [];
@Watch('onItemsChange') /* 当 items 变化时 */
private itemsRef = this.items;
onItemsChange() { console.log('items changed'); }
```

## 6. 路由 / 导航

新版推荐 **Navigation 组件** + **NavPathStack**（API 11+）：

```typescript
@Entry @Component
struct App {
  pageStack: NavPathStack = new NavPathStack();

  build() {
    Navigation(this.pageStack) {
      Button('go detail').onClick(() => {
        this.pageStack.pushPath({ name: 'Detail', param: { id: 1 } });
      });
    }
    .navDestination(this.PageMap)
    .title('Home');
  }

  @Builder
  PageMap(name: string, param: object) {
    if (name === 'Detail') {
      DetailPage({ param: param as { id: number } });
    }
  }
}

@Component
struct DetailPage {
  @Prop param: { id: number } = { id: 0 };
  build() {
    NavDestination() {
      Text(`id=${this.param.id}`);
    }.title('Detail');
  }
}
```

旧版 `router.pushUrl` 方式仍可用，但新项目建议直接采用 `NavPathStack`。

## 7. 动画

```typescript
@State scale: number = 1;

build() {
  Image($r('app.media.icon'))
    .scale({ x: this.scale, y: this.scale })
    .animation({ duration: 300, curve: Curve.EaseInOut })
    .onClick(() => this.scale = this.scale === 1 ? 1.5 : 1);
}
```

显式动画：

```typescript
animateTo({ duration: 500 }, () => {
  this.x = 100;
  this.y = 200;
});
```

## 8. 资源

```typescript
// 字符串
Text($r('app.string.app_name'))
// 颜色
Text(...).fontColor($r('sys.color.ohos_id_color_primary'))
// 图片
Image($r('app.media.icon'))
```

`resources/base/element/string.json`：

```json
{
  "string": [
    { "name": "app_name", "value": "HelloHarmony" }
  ]
}
```

## 9. 进阶

- **@Reusable 复用池化**：长列表性能优化
- **LazyForEach + DataSource**：数据驱动的虚拟列表
- **自定义组件库（HAR / HSP）**：抽出可复用 UI
- **Canvas / NodeContainer**：自定义绘制

## 10. 推荐学习路径

1. 先看 `upstream-docs/.../ui/Readme-CN.md` 总览
2. 跟着 `upstream-docs/.../quick-start/start-with-ets-stage.md` 写一个 demo
3. 重点啃 `state-management/` 全部章节
4. 翻 `reference/apis-arkui/arkui-ts/` 当组件字典
5. 模仿 `third-party-cases/`（社区案例）做一个完整页面
