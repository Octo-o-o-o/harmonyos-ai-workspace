// Local Test（纯逻辑单测）· 放 entry/src/test/ets/test/
// verified_against: harmonyos-6.1.1-api24 · docs-checked 2026-07-09
// 铁律：这里不能 import 任何 @kit.* 系统模块——Local 环境没有系统 API 实现。
import { describe, it, expect, beforeAll } from '@ohos/hypium';

// 被测对象示例：纯逻辑 service（真实工程里 import 你自己的类）
class PriceCalculator {
  private taxRate: number = 0.06;

  totalWithTax(subtotal: number): number {
    if (subtotal < 0) {
      throw new Error('subtotal must be >= 0');
    }
    return Math.round(subtotal * (1 + this.taxRate) * 100) / 100;
  }

  applyCoupon(subtotal: number, off: number): number {
    const result = subtotal - off;
    return result > 0 ? result : 0;
  }
}

export default function calcLogicTest() {
  describe('CalcLogicTest', () => {
    let calc: PriceCalculator = new PriceCalculator();

    beforeAll(() => {
      calc = new PriceCalculator();
    });

    it('total_with_tax_rounds_to_cents', 0, () => {
      expect(calc.totalWithTax(100)).assertEqual(106);
      expect(calc.totalWithTax(9.99)).assertEqual(10.59);
    });

    it('total_with_tax_rejects_negative', 0, () => {
      // 断言抛错：函数包一层再交给 assertThrowError
      expect(() => calc.totalWithTax(-1)).assertThrowError('subtotal must be >= 0');
    });

    it('coupon_never_goes_negative', 0, () => {
      expect(calc.applyCoupon(30, 50)).assertEqual(0);
      expect(calc.applyCoupon(50, 30)).assertEqual(20);
    });

    // 异步逻辑示例：必须调 done()，否则按超时失败。
    // 测试代码不包 try——异常抛出 = 用例失败，正是框架期望的行为。
    it('async_logic_calls_done', 0, async (done: Function) => {
      // scan-ignore: ARKTS-AWAIT-TRY
      const v: number = await Promise.resolve(42);
      expect(v).assertEqual(42);
      done();
    });
  });
}
