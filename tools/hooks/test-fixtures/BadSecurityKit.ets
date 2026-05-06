// Test fixture · 触发 v0.3 新增规则
// 期望钩子命中：SEC-002, SEC-007, DB-001, KIT-002, AGC-RJ-014, PERF-002

import { hilog } from '@kit.PerformanceAnalysisKit';
import { relationalStore } from '@kit.ArkData';
import { image } from '@kit.ImageKit';

const DOMAIN = 0xBEEF;

class App {
  // SEC-002: 用 %{public} 输出 token
  logUser(token: string): void {
    hilog.info(DOMAIN, 'auth', 'login token=%{public}s', token);
  }

  // SEC-007: 用了 MD5 弱算法（注释一下就触发）
  hashPassword(pwd: string): string {
    return MD5.hash(pwd);   // SEC-007
  }

  // DB-001: ResultSet 没 close
  async loadUsers(store: relationalStore.RdbStore): Promise<void> {
    const rs = await store.getResultSet('SELECT * FROM users');
    while (rs.goToNextRow()) {
      // ... 处理每一行
    }
    // 漏了 rs.close()
  }

  // KIT-002: ImageSource 不 release
  async decodeImage(buf: ArrayBuffer): Promise<void> {
    const imageSource = image.createImageSource(buf);
    const px = await imageSource.createPixelMap();
    // 漏了 imageSource.release()
  }
}

@Entry
@Component
struct Page {
  @State users: string[] = [];

  build() {
    Column() {
      // AGC-RJ-014: 硬编码中文
      Text('用户列表');
      Text('请登录以继续');

      // PERF-002: ForEach 长列表（数据多时应用 LazyForEach）
      ForEach(this.users, (u: string) => {
        Text(u)
      })

      // 一些占位行让文件超过 80 行（PERF-002 触发条件）
      Text('placeholder 1')
      Text('placeholder 2')
      Text('placeholder 3')
      Text('placeholder 4')
      Text('placeholder 5')
      Text('placeholder 6')
      Text('placeholder 7')
      Text('placeholder 8')
      Text('placeholder 9')
      Text('placeholder 10')
      Text('placeholder 11')
      Text('placeholder 12')
      Text('placeholder 13')
      Text('placeholder 14')
      Text('placeholder 15')
      Text('placeholder 16')
      Text('placeholder 17')
      Text('placeholder 18')
      Text('placeholder 19')
      Text('placeholder 20')
      Text('placeholder 21')
      Text('placeholder 22')
      Text('placeholder 23')
      Text('placeholder 24')
      Text('placeholder 25')
      Text('placeholder 26')
      Text('placeholder 27')
      Text('placeholder 28')
      Text('placeholder 29')
      Text('placeholder 30')
    }
  }
}
