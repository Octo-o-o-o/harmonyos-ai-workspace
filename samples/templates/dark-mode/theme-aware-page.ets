// Recipe · 深色模式 · 系统主题跟随
// verified_against: harmonyos-6.0.2-api22

import { mediaquery } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xBEEF;

@Entry
@Component
struct ThemeAwarePage {
  @State isDark: boolean = false;
  private listener: mediaquery.MediaQueryListener | null = null;

  aboutToAppear(): void {
    // 仅当你需要"代码层"响应主题切换时才用 mediaquery
    // 单纯换 UI 颜色 / 图标 → 用资源限定符就够，不需要这段
    this.listener = mediaquery.matchMediaSync('(dark-mode: true)');
    this.isDark = this.listener.matches;
    this.listener.on('change', (result) => {
      this.isDark = result.matches;
      hilog.info(DOMAIN, 'theme', 'dark-mode changed: %{public}s', `${this.isDark}`);
    });
  }

  aboutToDisappear(): void {
    this.listener?.off('change');
    this.listener = null;
  }

  build() {
    Column({ space: 12 }) {
      // ✅ 推荐：用 app 资源色（跟随浅 / 深资源文件自动切换）
      Text('标题')
        .fontSize(24)
        .fontColor($r('app.color.text_primary'))

      Text('副标题')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))

      // ✅ 推荐：直接用系统色（更省心，但可定制性低）
      Text('系统色版本')
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))

      // ❌ 反模式：写死十六进制
      // Text('永远黑色').fontColor('#000000')   // 深色模式下看不见

      // 进阶：根据 isDark 切换非颜色逻辑（如换不同的图标资源）
      Image(this.isDark ? $r('app.media.logo_dark') : $r('app.media.logo_light'))
        .width(120)
        .height(40)

      Text(`当前主题：${this.isDark ? '深色' : '浅色'}`)
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
    .padding(16)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
