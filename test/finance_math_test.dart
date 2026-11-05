import 'package:campus_wallet/core/logic/finance_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinanceMath 决策表', () {
    test('R1 monthly：发钱日未到 -> 本月该日', () {
      final next = FinanceMath.nextPayDate(
        periodType: 'monthly',
        payDay: 15,
        today: DateTime(2026, 11, 10),
      );
      expect(next, DateTime(2026, 11, 15));
    });

    test('R1 monthly：发钱日已过 -> 下月该日', () {
      final next = FinanceMath.nextPayDate(
        periodType: 'monthly',
        payDay: 15,
        today: DateTime(2026, 11, 20),
      );
      expect(next, DateTime(2026, 12, 15));
    });

    test('R1 monthly：今天就是发钱日 -> 今天', () {
      final next = FinanceMath.nextPayDate(
        periodType: 'monthly',
        payDay: 15,
        today: DateTime(2026, 11, 15),
      );
      expect(next, DateTime(2026, 11, 15));
    });

    test('R1 monthly：发钱日 31 在 4 月截断为 30', () {
      final next = FinanceMath.nextPayDate(
        periodType: 'monthly',
        payDay: 31,
        today: DateTime(2026, 4, 10),
      );
      expect(next, DateTime(2026, 4, 30));
    });

    test('R2 every_n_days：已过期则滚动到下一周期', () {
      final next = FinanceMath.nextPayDate(
        periodType: 'every_n_days',
        lastPayDate: DateTime(2026, 10, 20),
        everyNDays: 30,
        today: DateTime(2026, 11, 25),
      );
      expect(next, DateTime(2026, 12, 19));
    });

    test('R2 every_n_days：未过期直接用上次+N', () {
      final next = FinanceMath.nextPayDate(
        periodType: 'every_n_days',
        lastPayDate: DateTime(2026, 10, 20),
        everyNDays: 30,
        today: DateTime(2026, 11, 10),
      );
      expect(next, DateTime(2026, 11, 19));
    });

    test('距下次发钱天数', () {
      final d = FinanceMath.daysToNextPay(
        periodType: 'monthly',
        payDay: 15,
        today: DateTime(2026, 11, 10),
      );
      expect(d, 5);
    });

    test('R3 剩余可用可为负', () {
      expect(
        FinanceMath.remainingCents(
          monthlyBudgetCents: 200000,
          monthExpenseCents: 250000,
        ),
        -50000,
      );
    });

    test('R4 超支时日均可用为 0', () {
      expect(
        FinanceMath.dailyAvailable(remainingCents: -5000, daysToNextPay: 5),
        0,
      );
    });

    test('R4 日均可用计算', () {
      expect(
        FinanceMath.dailyAvailable(remainingCents: 100000, daysToNextPay: 4),
        25000,
      );
    });

    test('R6 分类配额进度；未设配额为 0', () {
      expect(
        FinanceMath.categoryProgress(spentCents: 3000, limitCents: 10000),
        closeTo(0.3, 1e-9),
      );
      expect(
        FinanceMath.categoryProgress(spentCents: 3000, limitCents: 0),
        0,
      );
    });

    test('monthKey 格式 YYYY-MM', () {
      expect(FinanceMath.monthKey(DateTime(2026, 1, 5)), '2026-01');
    });
  });
}