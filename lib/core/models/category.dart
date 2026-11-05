/// 分类模型（契约：禁止改字段）
class Category {
  static const typeExpense = 'expense';
  static const typeIncome = 'income';

  final int? id;
  final String name;
  final String type; // 'expense' | 'income'
  final String icon; // 内置图标名，见 widgets/category_icon.dart
  final int color; // ARGB int
  final int sort;
  final bool builtin;

  const Category({
    this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.sort,
    this.builtin = false,
  });

  bool get isExpense => type == typeExpense;

  Category copyWith({
    int? id,
    String? name,
    String? type,
    String? icon,
    int? color,
    int? sort,
    bool? builtin,
  }) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        sort: sort ?? this.sort,
        builtin: builtin ?? this.builtin,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'icon': icon,
        'color': color,
        'sort': sort,
        'builtin': builtin ? 1 : 0,
      };

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: m['type'] as String,
        icon: m['icon'] as String,
        color: m['color'] as int,
        sort: m['sort'] as int,
        builtin: (m['builtin'] as int? ?? 0) == 1,
      );
}