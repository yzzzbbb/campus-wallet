import 'package:campus_wallet/core/logic/recurring_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecurringMath 顺延规则', () {
    test('monthly：到期日未到 -> 本月该日', () {
      final next = RecurringMath.nextDueDate(
        periodType: RecurringBillLike.monthly,
        periodValue: 15,
        currentDue: DateTime(2026, 10, 15),
        from: DateTime(2026, 11, 10),
      );
      expect(next, DateTime(2026, 11, 15));
    });

    test('monthly：已过期 -> 下月该日', () {
      final next = RecurringMath.nextDueDate(
        periodType: RecurringBillLike.monthly,
        periodValue: 15,
        currentDue: DateTime(2026, 10, 15),
        from: DateTime(2026, 11, 20),
      );
      expect(next, DateTime(2026, 12, 15));
    });

    test('monthly：到期日当天入账 -> 顺延到下月', () {
      final next = RecurringMath.nextDueDate(
        periodType: RecurringBillLike.monthly,
        periodValue: 15,
        currentDue: DateTime(2026, 11, 15),
        from: DateTime(2026, 11, 15),
      );
      expect(next, DateTime(2026, 12, 15));
    });

    test('monthly：31 号在 4 月截断为 30', () {
      final next = RecurringMath.nextDueDate(
        periodType: RecurringBillLike.monthly,
        periodValue: 31,
        currentDue: DateTime(2026, 3, 31),
        from: DateTime(2026, 4, 10),
      );
      expect(next, DateTime(2026, 4, 30));
    });

    test('every_n_days：滚动到 >= from', () {
      final next = RecurringMath.nextDueDate(
        periodType: RecurringBillLike.everyNDays,
        periodValue: 7,
        currentDue: DateTime(2026, 11, 1),
        from: DateTime(2026, 11, 20),
      );
      expect(next, DateTime(2026, 11, 22));
    });

    test('every_n_days：未过期直接 +N', () {
      final next = RecurringMath.nextDueDate(
        periodType: RecurringBillLike.everyNDays,
        periodValue: 7,
        currentDue: DateTime(2026, 11, 15),
        from: DateTime(2026, 11, 10),
      );
      expect(next, DateTime(2026, 11, 22));
    });
  });
}