/// 预算提醒决策逻辑（纯函数，可测）
class AlertLogic {
  AlertLogic._();

  /// 预算使用率档位：<0.8 无提醒；0.8~1.0 提醒；>=1.0 超支
  static String levelForUsage(double usage) {
    if (usage >= 1.0) return 'over';
    if (usage >= 0.8) return 'warn';
    return 'none';
  }

  /// 今天是否应该提醒：
  /// - 同一天只提醒一次（日期字符串不同才考虑）
  /// - 级别不高于上次已提醒级别时不重复提醒
  static bool shouldAlert({
    required String lastAlertDate, // 'YYYY-MM-DD'，空字符串表示从未提醒
    required String lastLevel, // '' / 'warn' / 'over'
    required String today, // 'YYYY-MM-DD'
    required String newLevel, // 'none' / 'warn' / 'over'
  }) {
    if (newLevel == 'none') return false;
    if (lastAlertDate == today) return false;
    const ranks = {'warn': 1, 'over': 2};
    final lastRank = ranks[lastLevel] ?? 0;
    final newRank = ranks[newLevel] ?? 0;
    if (newRank <= lastRank) return false;
    return true;
  }

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}