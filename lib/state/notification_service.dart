import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/logic/alert_logic.dart';

/// 本地通知服务：初始化、权限、预算提醒（纯本地，无网络）
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) {},
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true; // 非安卓平台直接视为可用
    return await android.requestNotificationsPermission() ?? false;
  }

  /// 预算提醒通知；[usage] 为预算使用率（0.3 表示 30%）
  Future<void> showBudgetAlert({required double usage}) async {
    final level = AlertLogic.levelForUsage(usage);
    if (level == 'none') return;
    final body = level == 'over'
        ? '本月预算已超支！去看看哪些分类花多了吧'
        : '本月预算已用 ${(usage * 100).round()}%，注意控制开销';
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'budget_alerts',
        '预算提醒',
        channelDescription: '预算使用率与超支提醒',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    try {
      await _plugin.show(
        id: 1001,
        title: level == 'over' ? '预算超支警告' : '预算提醒',
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('通知发送失败：$e');
    }
  }
}