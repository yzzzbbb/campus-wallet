/// 流水模型（契约：禁止改字段）
class Transaction {
  static const typeExpense = 'expense';
  static const typeIncome = 'income';

  final int? id;
  final String type; // 'expense' | 'income'
  final int amountCents; // 金额以分存储，恒为正
  final int categoryId;
  final int? accountId; // 账户 id，null 表示未指定
  final String note;
  final DateTime occurredAt;
  final DateTime createdAt;

  Transaction({
    this.id,
    required this.type,
    required this.amountCents,
    required this.categoryId,
    this.accountId,
    this.note = '',
    required this.occurredAt,
    required this.createdAt,
  });

  bool get isExpense => type == typeExpense;

  Transaction copyWith({
    int? id,
    String? type,
    int? amountCents,
    int? categoryId,
    int? accountId,
    String? note,
    DateTime? occurredAt,
    DateTime? createdAt,
  }) =>
      Transaction(
        id: id ?? this.id,
        type: type ?? this.type,
        amountCents: amountCents ?? this.amountCents,
        categoryId: categoryId ?? this.categoryId,
        accountId: accountId ?? this.accountId,
        note: note ?? this.note,
        occurredAt: occurredAt ?? this.occurredAt,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount_cents': amountCents,
        'category_id': categoryId,
        'account_id': accountId,
        'note': note,
        'occurred_at': occurredAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory Transaction.fromMap(Map<String, dynamic> m) => Transaction(
        id: m['id'] as int?,
        type: m['type'] as String,
        amountCents: m['amount_cents'] as int,
        categoryId: m['category_id'] as int,
        accountId: m['account_id'] as int?,
        note: m['note'] as String? ?? '',
        occurredAt: DateTime.parse(m['occurred_at'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}