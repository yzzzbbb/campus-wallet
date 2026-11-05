import 'package:flutter/foundation.dart';

import '../core/data/dao.dart';
import '../core/logic/finance_math.dart';
import '../core/models/budget_setting.dart';
import '../core/models/category_budget.dart';

/// 预算/生活费设置状态（契约：禁止改公开方法签名）
class BudgetProvider extends ChangeNotifier {
  static const kAllowanceAmount = 'allowance_amount_cents';
  static const kPeriodType = 'allowance_period_type';
  static const kPayDay = 'allowance_pay_day';
  static const kEveryNDays = 'allowance_every_n_days';
  static const kLastPayDate = 'last_pay_date';
  static const kMonthlyBudget = 'monthly_budget_cents';

  BudgetSetting _setting = const BudgetSetting();
  bool _loaded = false;
  final Map<String, List<CategoryBudget>> _budgetCache = {};

  BudgetSetting get setting => _setting;
  bool get loaded => _loaded;

  Future<void> load() async {
    final d = Dao.instance;
    _setting = BudgetSetting(
      allowanceAmountCents: _parseInt(await d.getSetting(kAllowanceAmount), 0),
      periodType: (await d.getSetting(kPeriodType)) ??
          BudgetSetting.periodMonthly,
      payDay: _parseInt(await d.getSetting(kPayDay), 1),
      everyNDays: _parseInt(await d.getSetting(kEveryNDays), 30),
      lastPayDate: _parseDate(await d.getSetting(kLastPayDate)),
      monthlyBudgetCents: _parseNullableInt(await d.getSetting(kMonthlyBudget)),
    );
    _loaded = true;
    notifyListeners();
  }

  Future<void> saveSetting(BudgetSetting s) async {
    final d = Dao.instance;
    await d.setSetting(kAllowanceAmount, s.allowanceAmountCents.toString());
    await d.setSetting(kPeriodType, s.periodType);
    await d.setSetting(kPayDay, s.payDay.toString());
    await d.setSetting(kEveryNDays, s.everyNDays.toString());
    if (s.lastPayDate != null) {
      final lp = s.lastPayDate!;
      final dateStr =
          '${lp.year.toString().padLeft(4, '0')}-${lp.month.toString().padLeft(2, '0')}-${lp.day.toString().padLeft(2, '0')}';
      await d.setSetting(kLastPayDate, dateStr);
    }
    if (s.monthlyBudgetCents != null) {
      await d.setSetting(kMonthlyBudget, s.monthlyBudgetCents.toString());
    }
    _setting = s;
    notifyListeners();
  }

  /// 距下次发生活费天数（R1/R2，>= 0）
  int get daysToNextPay => FinanceMath.daysToNextPay(
        periodType: _setting.periodType,
        payDay: _setting.payDay,
        lastPayDate: _setting.lastPayDate,
        everyNDays: _setting.everyNDays,
        today: DateTime.now(),
      );

  /// R7：有效月预算总额
  int get effectiveMonthlyBudgetCents => _setting.effectiveMonthlyBudgetCents();

  Future<List<CategoryBudget>> budgetsOfMonth(String month) async {
    final cached = _budgetCache[month];
    if (cached != null) return cached;
    final list = await Dao.instance.budgetsOfMonth(month);
    _budgetCache[month] = list;
    return list;
  }

  Future<void> setCategoryBudget({
    required int categoryId,
    required String month,
    required int limitCents,
  }) async {
    await Dao.instance.setCategoryBudget(
      categoryId: categoryId,
      month: month,
      limitCents: limitCents,
    );
    _budgetCache.remove(month);
    notifyListeners();
  }

  static int _parseInt(String? s, int fallback) =>
      s == null ? fallback : (int.tryParse(s) ?? fallback);

  static int? _parseNullableInt(String? s) =>
      s == null ? null : int.tryParse(s);

  static DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}