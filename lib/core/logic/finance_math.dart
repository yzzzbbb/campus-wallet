/// 决策表 R1~R10 的纯函数实现（PRD.md 第 3 节）。
/// 禁止引入 UI / DB 依赖，禁止修改本文件。
class FinanceMath {
  FinanceMath._();

  /// 'YYYY-MM'
  static String monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// R1/R2：下次发生活费日期（date-only 语义）。
  /// periodType: 'monthly'（每月固定日，用 payDay）| 'every_n_days'（每 N 天，用 lastPayDate + everyNDays）
  static DateTime nextPayDate({
    required String periodType,
    int payDay = 1,
    DateTime? lastPayDate,
    int everyNDays = 30,
    required DateTime today,
  }) {
    final t = DateTime(today.year, today.month, today.day);
    if (periodType == 'every_n_days') {
      if (lastPayDate == null) return t; // 未设置，UI 引导
      final lp =
          DateTime(lastPayDate.year, lastPayDate.month, lastPayDate.day);
      var next = lp.add(Duration(days: everyNDays));
      while (next.isBefore(t)) {
        next = next.add(Duration(days: everyNDays));
      }
      return next;
    }
    // monthly：本月 d 日已过 → 下月 d 日；未过（含今天）→ 本月 d 日；月底自动截断
    final d = payDay < 1 ? 1 : (payDay > 31 ? 31 : payDay);
    final thisMonthDay =
        d > daysInMonth(t.year, t.month) ? daysInMonth(t.year, t.month) : d;
    var next = DateTime(t.year, t.month, thisMonthDay);
    if (next.isBefore(t)) {
      final nm = DateTime(t.year, t.month + 1, 1);
      final nd =
          d > daysInMonth(nm.year, nm.month) ? daysInMonth(nm.year, nm.month) : d;
      next = DateTime(nm.year, nm.month, nd);
    }
    return next;
  }

  /// 距下次发生活费天数（>= 0）
  static int daysToNextPay({
    required String periodType,
    int payDay = 1,
    DateTime? lastPayDate,
    int everyNDays = 30,
    required DateTime today,
  }) {
    final next = nextPayDate(
      periodType: periodType,
      payDay: payDay,
      lastPayDate: lastPayDate,
      everyNDays: everyNDays,
      today: today,
    );
    final t = DateTime(today.year, today.month, today.day);
    return next.difference(t).inDays;
  }

  /// R3：剩余可用（可为负）
  static int remainingCents({
    required int monthlyBudgetCents,
    required int monthExpenseCents,
  }) =>
      monthlyBudgetCents - monthExpenseCents;

  /// R4：日均可用；剩余 <= 0 时返回 0
  static double dailyAvailable({
    required int remainingCents,
    required int daysToNextPay,
  }) {
    if (remainingCents <= 0) return 0;
    return remainingCents / (daysToNextPay < 1 ? 1 : daysToNextPay);
  }

  /// R6：分类配额进度（0 起，可为 > 1）；配额未设/为 0 返回 0
  static double categoryProgress({
    required int spentCents,
    required int limitCents,
  }) {
    if (limitCents <= 0) return 0;
    return spentCents / limitCents;
  }
}