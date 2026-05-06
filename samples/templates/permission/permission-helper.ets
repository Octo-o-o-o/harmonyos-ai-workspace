// Recipe · 权限申请助手
// verified_against: harmonyos-6.0.2-api22
//
// 用法：
//   const ok = await requestPermissionWithUI('ohos.permission.LOCATION', '推荐附近服务');
//   if (!ok) { /* 兜底逻辑：手动输入 / 跳过功能 */ }

import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0xBEEF;

/**
 * 申请单个权限（带 UI 解释 + 拒绝兜底）。
 * AGC 提审要求：每个敏感权限必须先弹窗解释才能申请。
 */
export async function requestPermissionWithUI(
  permission: Permissions,
  scenario: string,
): Promise<boolean> {
  const ctx = getContext() as common.UIAbilityContext;
  const atManager = abilityAccessCtrl.createAtManager();

  // 1. 检查当前授权状态——已授权直接返回
  try {
    const tokenId = ctx.applicationInfo.accessTokenId;
    const status = await atManager.checkAccessToken(tokenId, permission);
    if (status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
      return true;
    }
  } catch (e) {
    const err = e as BusinessError;
    hilog.warn(DOMAIN, 'perm', 'check failed: code=%{public}d', err.code);
  }

  // 2. 先弹窗解释用途（AGC 要求）
  try {
    const dialog = await promptAction.showDialog({
      title: '权限申请',
      message: `${scenario}\n\n拒绝后你仍可使用其他功能，但本特性会受限。`,
      buttons: [
        { text: '不允许', color: '#666666' },
        { text: '继续', color: '#0A59F7' },
      ],
    });
    if (dialog.index !== 1) {
      return false;
    }
  } catch (e) {
    return false;
  }

  // 3. 真正申请
  try {
    const result = await atManager.requestPermissionsFromUser(ctx, [permission]);
    return result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  } catch (e) {
    const err = e as BusinessError;
    hilog.error(DOMAIN, 'perm', 'request failed: code=%{public}d msg=%{public}s', err.code, err.message);
    return false;
  }
}

/**
 * 4 个最常见权限的便捷封装。
 */
export class CommonPermissions {
  static location(): Promise<boolean> {
    return requestPermissionWithUI('ohos.permission.LOCATION', '用于推荐附近的服务点');
  }

  static camera(): Promise<boolean> {
    return requestPermissionWithUI('ohos.permission.CAMERA', '用于扫码或拍照');
  }

  static microphone(): Promise<boolean> {
    return requestPermissionWithUI('ohos.permission.MICROPHONE', '用于语音输入');
  }

  // 通知权限在 API 12+ 是单独的 API（不走 atManager）
  static async notification(): Promise<boolean> {
    // 见 @kit.NotificationKit 的 notificationManager.requestEnableNotification
    // 此处省略——具体见 references/official-docs.md
    return false;
  }
}
