/// 周期账单顺延规则（纯函数，无 UI / DB 依赖）
class RecurringMath {
  RecurringMath._();

  /// 计算 > [from] 的下一次到期日（当天入账也顺延到下一周期）。
  /// - monthly：每月 [periodValue] 号（月底自动截断）
  /// - every_n_days：从 [currentDue] 起每 [periodValue] 天滚动到 > [from]
  static DateTime nextDueDate({
    required String periodType,
    required int periodValue,
    required DateTime currentDue,
    required DateTime from,
  }) {
    final f = DateTime(from.year, from.month, from.day);
    if (periodType == RecurringBillLike.everyNDays) {
      final n = periodValue < 1 ? 1 : periodValue;
      var next = DateTime(currentDue.year, currentDue.month, currentDue.day)
          .add(Duration(days: n));
      while (!next.isAfter(f)) {
        next = next.add(Duration(days: n));
      }
      return next;
    }
    // monthly
    final d = periodValue < 1 ? 1 : (periodValue > 31 ? 31 : periodValue);
    int daysIn(int y, int m) => DateTime(y, m + 1, 0).day;
    final day = d > daysIn(f.year, f.month) ? daysIn(f.year, f.month) : d;
    var next = DateTime(f.year, f.month, day);
    if (!next.isAfter(f)) {
      final nm = DateTime(f.year, f.month + 1, 1);
      final nd = d > daysIn(nm.year, nm.month) ? daysIn(nm.year, nm.month) : d;
      next = DateTime(nm.year, nm.month, nd);
    }
    return next;
  }
}

/// 周期类型常量别名（避免直接依赖模型层）
abstract final class RecurringBillLike {
  static const monthly = 'monthly';
  static const everyNDays = 'every_n_days';
}