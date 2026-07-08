// Instrument Test（UI 自动化）· 放 entry/src/ohosTest/ets/test/
// verified_against: harmonyos-6.1.1-api24 · docs-checked 2026-07-09
// 前置：被测页面的关键控件已加 .id()（如 TextInput().id('accountInput')、Button().id('loginBtn')）
import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit';
import { Want } from '@kit.AbilityKit';

const delegator = abilityDelegatorRegistry.getAbilityDelegator();

export default function loginPageUiTest() {
  describe('LoginPageUiTest', () => {
    it('launch_ability_then_login_flow', 0, async (done: Function) => {
      // 1) 启动被测 Ability（bundleName 从测试参数自动取，不硬编码）
      //    测试代码不包 try——异常抛出 = 用例失败，正是框架期望的行为。
      const bundleName: string = abilityDelegatorRegistry.getArguments().bundleName;
      const want: Want = { bundleName: bundleName, abilityName: 'EntryAbility' };
      // scan-ignore: ARKTS-AWAIT-TRY
      await delegator.startAbility(want);

      // 2) 等界面稳定：waitForIdle 优于堆 delayMs
      const driver: Driver = Driver.create();
      await driver.waitForIdle(4000, 5000);

      // 3) 按 id 定位输入框并输入（坐标定位换设备必挂，禁用）
      const account = await driver.findComponent(ON.id('accountInput'));
      expect(account !== null).assertTrue();
      await account.clearText();
      await account.inputText('test_account');

      // 4) 点击登录
      const loginBtn = await driver.findComponent(ON.id('loginBtn'));
      expect(loginBtn !== null).assertTrue();
      await loginBtn.click();

      // 5) 等目标页出现：waitForComponent 带超时轮询
      const homeMarker = await driver.waitForComponent(ON.id('homePageRoot'), 3000);
      expect(homeMarker !== null).assertTrue();

      // 6) 失败排查时留截图证据
      // await driver.screenCap('/data/local/tmp/login_flow.png');

      done();
    });
  });
}
