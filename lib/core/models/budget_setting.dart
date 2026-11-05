/// 生活费 / 预算设置（契约：禁止改字段）
/// 持久化在 settings 表，键见 [BudgetProvider]。
class BudgetSetting {
  static const periodMonthly = 'monthly';
  static const periodEveryNDays = 'every_n_days';

  final int allowanceAmountCents; // 生活费金额（分）
  final String periodType; // 'monthly' | 'every_n_days'
  final int payDay; // 1..31，仅 monthly 用
  final int everyNDays; // 每 N 天，仅 every_n_days 用
  final DateTime? lastPayDate; // 上次发钱日（every_n_days 用）
  final int? monthlyBudgetCents; // 手动月预算；null = 用生活费金额（R7）

  const BudgetSetting({
    this.allowanceAmountCents = 0,
    this.periodType = periodMonthly,
    this.payDay = 1,
    this.everyNDays = 30,
    this.lastPayDate,
    this.monthlyBudgetCents,
  });

  /// 是否已完成生活费基础设置
  bool get isConfigured => allowanceAmountCents > 0;

  /// R7：有效月预算总额
  int effectiveMonthlyBudgetCents() =>
      monthlyBudgetCents ?? allowanceAmountCents;

  BudgetSetting copyWith({
    int? allowanceAmountCents,
    String? periodType,
    int? payDay,
    int? everyNDays,
    DateTime? lastPayDate,
    int? monthlyBudgetCents,
    bool clearMonthlyBudget = false,
  }) =>
      BudgetSetting(
        allowanceAmountCents: allowanceAmountCents ?? this.allowanceAmountCents,
        periodType: periodType ?? this.periodType,
        payDay: payDay ?? this.payDay,
        everyNDays: everyNDays ?? this.everyNDays,
        lastPayDate: lastPayDate ?? this.lastPayDate,
        monthlyBudgetCents: clearMonthlyBudget
            ? null
            : (monthlyBudgetCents ?? this.monthlyBudgetCents),
      );
}