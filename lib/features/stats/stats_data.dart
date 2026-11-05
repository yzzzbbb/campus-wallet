import '../../core/models/category.dart';
import '../../core/models/category_budget.dart';

/// 饼图数据项：分类名、金额（分）、颜色。
/// 纯数据，便于脱离 UI / DB 做单元测试。
class PieEntry {
  final String name;
  final int cents;
  final int color;

  const PieEntry({
    required this.name,
    required this.cents,
    required this.color,
  });
}

/// 超支分类数据项：分类名、超出金额（分，恒为正）。
class OverrunEntry {
  final String name;
  final int overspentCents;

  const OverrunEntry({
    required this.name,
    required this.overspentCents,
  });
}

/// 由「分类 id -> 当月支出（分）」构造饼图数据。
/// - 按金额降序排列；
/// - 在 [categories] 中找不到对应分类的条目跳过。
List<PieEntry> buildPieEntries({
  required Map<int, int> byCategory,
  required List<Category> categories,
}) {
  final categoryById = <int, Category>{
    for (final c in categories)
      if (c.id != null) c.id!: c,
  };

  final entries = <PieEntry>[
    for (final item in byCategory.entries)
      if (categoryById[item.key] != null)
        PieEntry(
          name: categoryById[item.key]!.name,
          cents: item.value,
          color: categoryById[item.key]!.color,
        ),
  ];

  entries.sort((a, b) => b.cents.compareTo(a.cents));
  return entries;
}

/// 由「分类 id -> 当月支出（分）」与分类配额计算超支分类 Top3。
/// - overspent = 支出 - 配额，仅当 > 0 时计入；
/// - 按超出金额降序，最多返回 3 条；
/// - 在 [categories] 中找不到对应分类的配额跳过。
List<OverrunEntry> buildOverrunTop3({
  required Map<int, int> byCategory,
  required List<Category> categories,
  required List<CategoryBudget> budgets,
}) {
  final categoryById = <int, Category>{
    for (final c in categories)
      if (c.id != null) c.id!: c,
  };

  final entries = <OverrunEntry>[];
  for (final budget in budgets) {
    final category = categoryById[budget.categoryId];
    if (category == null) continue;
    final spent = byCategory[budget.categoryId] ?? 0;
    final overspent = spent - budget.limitCents;
    if (overspent <= 0) continue;
    entries.add(OverrunEntry(name: category.name, overspentCents: overspent));
  }

  entries.sort((a, b) => b.overspentCents.compareTo(a.overspentCents));
  return entries.take(3).toList();
}

/// 年度月度总计（年度柱状图）
class MonthTotal {
  final int month; // 1..12
  final int cents;

  const MonthTotal({required this.month, required this.cents});
}

/// 由「'YYYY-MM' -> 支出」构造某年 12 个月总计（缺失月为 0）
List<MonthTotal> buildYearMonthly({
  required int year,
  required Map<String, int> expenseByMonth,
}) {
  return [
    for (var m = 1; m <= 12; m++)
      MonthTotal(
        month: m,
        cents: expenseByMonth[
                '${year.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}'] ??
            0,
      ),
  ];
}

/// 日历热力图单元
class DayCell {
  final DateTime date;
  final int cents;
  final int level; // -1 前导占位；0 无支出；1/2/3 支出强度

  const DayCell({required this.date, required this.cents, required this.level});
}

/// 热力图档位：0 无支出，1 少于 ¥20，2 少于 ¥100，3 其余
int heatLevelFor(int cents) {
  if (cents <= 0) return 0;
  if (cents < 2000) return 1;
  if (cents < 10000) return 2;
  return 3;
}

/// 周一起始的年度日历网格（前导占位补齐整周）
List<DayCell> buildCalendarCells({
  required int year,
  required Map<String, int> expenseByDay,
}) {
  final first = DateTime(year, 1, 1);
  final last = DateTime(year, 12, 31);
  final lead = (first.weekday - DateTime.monday) % 7;
  final cells = <DayCell>[];
  for (var i = 0; i < lead; i++) {
    cells.add(DayCell(
      date: first.subtract(Duration(days: lead - i)),
      cents: 0,
      level: -1,
    ));
  }
  for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
    final key = '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final cents = expenseByDay[key] ?? 0;
    cells.add(DayCell(date: d, cents: cents, level: heatLevelFor(cents)));
  }
  return cells;
}