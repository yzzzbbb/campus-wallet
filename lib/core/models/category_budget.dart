/// 分类配额模型（契约：禁止改字段）
class CategoryBudget {
  final int? id;
  final int categoryId;
  final String month; // 'YYYY-MM'
  final int limitCents;

  const CategoryBudget({
    this.id,
    required this.categoryId,
    required this.month,
    required this.limitCents,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'category_id': categoryId,
        'month': month,
        'limit_cents': limitCents,
      };

  factory CategoryBudget.fromMap(Map<String, dynamic> m) => CategoryBudget(
        id: m['id'] as int?,
        categoryId: m['category_id'] as int,
        month: m['month'] as String,
        limitCents: m['limit_cents'] as int,
      );
}