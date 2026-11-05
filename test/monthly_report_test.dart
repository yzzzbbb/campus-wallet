import 'package:campus_wallet/features/stats/monthly_report.dart';
import 'package:campus_wallet/features/stats/stats_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('budgetCompletionText：百分比与未设置', () {
    expect(budgetCompletionText(20000, 100000), '20.0%');
    expect(budgetCompletionText(100000, 100000), '100.0%');
    expect(budgetCompletionText(150000, 100000), '150.0%');
    expect(budgetCompletionText(0, 0), '未设置预算');
  });

  test('buildMonthlyReportData：标题、Top5 降序、超支保留', () {
    final data = buildMonthlyReportData(
      month: DateTime(2026, 11),
      totalExpenseCents: 40000,
      totalIncomeCents: 100000,
      budgetCents: 100000,
      pieEntries: [
        const PieEntry(name: '餐饮', cents: 25000, color: 0xFFFF7043),
        const PieEntry(name: '日用', cents: 10000, color: 0xFF42A5F5),
        const PieEntry(name: '交通', cents: 5000, color: 0xFF26A69A),
      ],
      overruns: const [
        OverrunEntry(name: '餐饮', overspentCents: 5000),
      ],
    );

    expect(data.monthTitle, '2026年11月');
    expect(data.totalExpenseCents, 40000);
    expect(data.topCategories, hasLength(3));
    expect(data.topCategories.first.name, '餐饮');
    expect(data.overruns, hasLength(1));
  });

  testWidgets('renderReportPng 输出合法 PNG', (tester) async {
    final data = buildMonthlyReportData(
      month: DateTime(2026, 11),
      totalExpenseCents: 40000,
      totalIncomeCents: 100000,
      budgetCents: 100000,
      pieEntries: const [
        PieEntry(name: '餐饮', cents: 25000, color: 0xFFFF7043),
        PieEntry(name: '日用', cents: 10000, color: 0xFF42A5F5),
      ],
      overruns: const [],
    );
    // toImage 是真实 GPU 异步操作，必须在真实事件循环里跑
    final png = (await tester.runAsync(() => renderReportPng(data)))!;
    expect(png.length, greaterThan(1000));
    // PNG 魔数
    expect(png[0], 0x89);
    expect(png[1], 0x50);
    expect(png[2], 0x4E);
    expect(png[3], 0x47);
  });
}