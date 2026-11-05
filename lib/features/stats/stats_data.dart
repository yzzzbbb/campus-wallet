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