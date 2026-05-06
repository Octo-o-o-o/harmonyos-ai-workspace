// Test fixture · 触发 ArkTS 严格语法反模式
// 期望钩子命中：ARKTS-001, 002, 003, 004, 005, 007, 009, 012, 014

import http from '@ohos.net.http';                  // ARKTS-014: 旧式 import

var globalCount = 0;                                // ARKTS-001: var

class Service {
  // ARKTS-002: 对象字面量无显式类型在用法处
  getUser(): Object {
    let user: any = { id: 1, name: 'a' };           // ARKTS-001: any
    return user;
  }

  loadDynamic(key: string): string {
    let obj: Object = { foo: 'bar', baz: 'qux' };
    return obj[key];                                // ARKTS-003: 动态索引
  }

  oldFunc = function (x: number): number {           // ARKTS-005: function 表达式
    return x + 1;
  };

  matchPhone(s: string): boolean {
    const re = /^1\d{10}$/;                         // ARKTS-007: regex 字面量
    return re.test(s);
  }

  iterate(o: Object): void {
    for (const k in o) {                             // ARKTS-009: for...in
      console.log(k);                                // ARKTS-012: console.log
    }
  }

  cleanup(o: Object): void {
    delete o['foo'];                                 // ARKTS-008: delete + ARKTS-003
  }

  destructTest(): void {
    const arr = [1, 2, 3];
    const [a, b] = arr;                              // ARKTS-004: 数组解构
    const obj = { x: 1, y: 2 };
    const { x, y } = obj;                            // ARKTS-004: 对象解构
  }

  toNumber(s: string): number {
    return +s;                                       // ARKTS-015: 一元 + 转字符串
  }
}
