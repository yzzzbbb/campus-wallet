/// 周期账单模型（订阅、话费、健身卡等固定周期支出）
class RecurringBill {
  static const periodMonthly = 'monthly';
  static const periodEveryNDays = 'every_n_days';

  final int? id;
  final String name;
  final int amountCents;
  final int categoryId;
  final String periodType; // 'monthly' | 'every_n_days'
  final int periodValue; // monthly: 每月几号(1..31)；every_n_days: 间隔天数
  final DateTime nextDueDate; // 下次到期日（date-only 语义）
  final String note;

  const RecurringBill({
    this.id,
    required this.name,
    required this.amountCents,
    required this.categoryId,
    required this.periodType,
    required this.periodValue,
    required this.nextDueDate,
    this.note = '',
  });

  RecurringBill copyWith({
    int? id,
    String? name,
    int? amountCents,
    int? categoryId,
    String? periodType,
    int? periodValue,
    DateTime? nextDueDate,
    String? note,
  }) =>
      RecurringBill(
        id: id ?? this.id,
        name: name ?? this.name,
        amountCents: amountCents ?? this.amountCents,
        categoryId: categoryId ?? this.categoryId,
        periodType: periodType ?? this.periodType,
        periodValue: periodValue ?? this.periodValue,
        nextDueDate: nextDueDate ?? this.nextDueDate,
        note: note ?? this.note,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'amount_cents': amountCents,
        'category_id': categoryId,
        'period_type': periodType,
        'period_value': periodValue,
        'next_due_date': _dateStr(nextDueDate),
        'note': note,
      };

  factory RecurringBill.fromMap(Map<String, dynamic> m) => RecurringBill(
        id: m['id'] as int?,
        name: m['name'] as String,
        amountCents: m['amount_cents'] as int,
        categoryId: m['category_id'] as int,
        periodType: m['period_type'] as String,
        periodValue: m['period_value'] as int,
        nextDueDate: DateTime.parse(m['next_due_date'] as String),
        note: m['note'] as String? ?? '',
      );

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}