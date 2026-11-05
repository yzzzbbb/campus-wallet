/// 账户模型：现金 / 饭卡 / 银行卡等，作为流水的归属标签
class Account {
  final int? id;
  final String name;
  final String icon;
  final int color;
  final int sort;
  final bool builtin;

  Account({
    this.id,
    required this.name,
    this.icon = 'account_balance_wallet',
    this.color = 0xFF16BD8C,
    this.sort = 0,
    this.builtin = false,
  });

  Account copyWith({
    int? id,
    String? name,
    String? icon,
    int? color,
    int? sort,
    bool? builtin,
  }) =>
      Account(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        sort: sort ?? this.sort,
        builtin: builtin ?? this.builtin,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'sort': sort,
        'builtin': builtin ? 1 : 0,
      };

  factory Account.fromMap(Map<String, dynamic> m) => Account(
        id: m['id'] as int?,
        name: m['name'] as String,
        icon: m['icon'] as String? ?? 'account_balance_wallet',
        color: m['color'] as int? ?? 0xFF16BD8C,
        sort: m['sort'] as int? ?? 0,
        builtin: (m['builtin'] as int? ?? 0) != 0,
      );
}