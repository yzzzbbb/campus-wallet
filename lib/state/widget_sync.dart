import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 桌面小组件同步：把倒计时摘要通过 MethodChannel 写入原生 SharedPreferences，
/// 由原生 AppWidgetProvider 读取并渲染到桌面。
class WidgetSync {
  WidgetSync._();

  static const _channel = MethodChannel('campus_wallet/widget');

  /// 更新桌面小组件数据（在 Android 上生效，其他平台静默忽略）
  static Future<void> syncSummary({
    required int days,
    required int remainingCents,
    required int dailyCents,
    required int monthExpenseCents,
  }) async {
    try {
      await _channel.invokeMethod('update', {
        'data': jsonEncode({
          'days': days,
          'remaining_cents': remainingCents,
          'daily_cents': dailyCents,
          'month_expense_cents': monthExpenseCents,
        }),
      });
    } catch (e) {
      debugPrint('桌面小组件同步失败：$e');
    }
  }
}