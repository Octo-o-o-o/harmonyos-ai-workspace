// Recipe · 长列表 + 下拉刷新 + 上拉加载
// verified_against: harmonyos-6.0.2-api22
//
// 关联规则：
//   PERF-002 长列表用 LazyForEach
//   STATE-002 替换引用而非就地 mutation（这里通过 ListDataSource 内部封装）
//
// 用法：
//   InfiniteList({
//     fetchPage: async (page) => await api.fetchUsers(page)
//   })

import { ListDataSource } from './item-data-source';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xBEEF;

interface Item {
  id: string;
  title: string;
  subtitle: string;
}

@Component
export struct InfiniteList {
  // 由调用方注入的页加载函数
  fetchPage: (page: number) => Promise<Item[]> = async () => [];

  @State refreshing: boolean = false;
  @State loadingMore: boolean = false;
  @State hasMore: boolean = true;
  @State page: number = 0;
  private data: ListDataSource<Item> = new ListDataSource();

  async aboutToAppear(): Promise<void> {
    await this.refresh();
  }

  async refresh(): Promise<void> {
    this.refreshing = true;
    this.page = 0;
    try {
      const items = await this.fetchPage(0);
      this.data.replace(items);
      this.hasMore = items.length > 0;
    } catch (e) {
      hilog.error(DOMAIN, 'list', 'refresh failed: %{public}s', JSON.stringify(e));
    } finally {
      this.refreshing = false;
    }
  }

  async loadMore(): Promise<void> {
    if (this.loadingMore || !this.hasMore) return;
    this.loadingMore = true;
    try {
      const next = this.page + 1;
      const items = await this.fetchPage(next);
      if (items.length === 0) {
        this.hasMore = false;
      } else {
        this.data.addBatch(items);
        this.page = next;
      }
    } catch (e) {
      hilog.error(DOMAIN, 'list', 'load more failed: %{public}s', JSON.stringify(e));
    } finally {
      this.loadingMore = false;
    }
  }

  build() {
    Refresh({ refreshing: $$this.refreshing }) {
      List() {
        // ⚠️ 第三参 keyGen 必须返回稳定 key（item.id），不要返回 index
        LazyForEach(this.data, (item: Item) => {
          ListItem() {
            Column() {
              Text(item.title).fontSize(16).fontWeight(FontWeight.Medium);
              Text(item.subtitle).fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'));
            }
            .padding(16)
            .alignItems(HorizontalAlign.Start)
            .width('100%')
          }
        }, (item: Item) => item.id)

        // 上拉加载提示——生产代码改用 $r('app.string.loading_more') 走 i18n
        if (this.loadingMore) {
          ListItem() {
            Text($r('app.string.loading_more')).padding(12).fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
        } else if (!this.hasMore) {
          ListItem() {
            Text($r('app.string.no_more_data')).padding(12).fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
        }
      }
      .onReachEnd(() => { this.loadMore() })
      .width('100%')
      .height('100%')
    }
    .onRefreshing(() => { this.refresh() })
  }
}
