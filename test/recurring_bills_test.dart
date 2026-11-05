import 'package:campus_wallet/core/data/app_database.dart';
import 'package:campus_wallet/core/data/dao.dart';
import 'package:campus_wallet/core/logic/finance_math.dart';
import 'package:campus_wallet/core/models/recurring_bill.dart';
import 'package:campus_wallet/core/models/transaction.dart';
import 'package:campus_wallet/features/bills/recurring_bills_page.dart';
import 'package:campus_wallet/features/home/home_page.dart';
import 'package:campus_wallet/state/budget_provider.dart';
import 'package:campus_wallet/state/category_provider.dart';
import 'package:campus_wallet/state/recurring_bills_provider.dart';
import 'package:campus_wallet/state/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    AppDatabase.instance.dbName = 'cw_test_bills.db';
    final path = p.join(
      await databaseFactory.getDatabasesPath(),
      'cw_test_bills.db',
    );
    if (await databaseFactory.databaseExists(path)) {
      await databaseFactory.deleteDatabase(path);
    }
    await AppDatabase.instance.database;
  });

  setUp(() async {
    await Dao.instance.clearAllData();
    await Dao.instance.clearRecurringBills();
    await Dao.instance.deleteCustomCategories();
  });

  Future<int> foodCategoryId() async {
    final cats = await Dao.instance.categories();
    return cats.firstWhere((c) => c.name == '餐饮').id!;
  }

  test('周期账单增改查删', () async {
    final provider = RecurringBillsProvider();
    final catId = await foodCategoryId();

    await provider.add(RecurringBill(
      name: '视频会员',
      amountCents: 1500,
      categoryId: catId,
      periodType: RecurringBill.periodMonthly,
      periodValue: 15,
      nextDueDate: DateTime(2026, 11, 15),
    ));
    var bills = await provider.bills();
    expect(bills, hasLength(1));
    expect(bills.first.name, '视频会员');

    await provider.update(bills.first.copyWith(name: '音乐会员'));
    bills = await provider.bills();
    expect(bills.first.name, '音乐会员');

    await provider.delete(bills.first.id!);
    expect(await provider.bills(), isEmpty);
  });

  test('dueBills 只返回已到期的账单', () async {
    final provider = RecurringBillsProvider();
    final catId = await foodCategoryId();
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final tomorrow = now.add(const Duration(days: 1));

    await provider.add(RecurringBill(
      name: '已过期账单',
      amountCents: 1000,
      categoryId: catId,
      periodType: RecurringBill.periodEveryNDays,
      periodValue: 30,
      nextDueDate: yesterday,
    ));
    await provider.add(RecurringBill(
      name: '未到期账单',
      amountCents: 2000,
      categoryId: catId,
      periodType: RecurringBill.periodEveryNDays,
      periodValue: 30,
      nextDueDate: tomorrow,
    ));

    final due = await provider.dueBills();
    expect(due, hasLength(1));
    expect(due.first.name, '已过期账单');
  });

  test('advance 顺延下次到期日', () async {
    final provider = RecurringBillsProvider();
    final catId = await foodCategoryId();

    await provider.add(RecurringBill(
      name: '话费',
      amountCents: 5000,
      categoryId: catId,
      periodType: RecurringBill.periodMonthly,
      periodValue: 15,
      nextDueDate: DateTime(2026, 11, 15),
    ));
    final bill = (await provider.bills()).first;
    await provider.advance(bill, DateTime(2026, 11, 15));
    final advanced = (await provider.bills()).first;
    expect(advanced.nextDueDate, DateTime(2026, 12, 15));
  });

  testWidgets('周期账单页：新增账单显示在列表', (tester) async {
    final provider = RecurringBillsProvider();
    final cp = CategoryProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider.value(value: cp),
        ],
        child: const MaterialApp(home: RecurringBillsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '名称（如：视频会员）'),
      '视频会员',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '金额（元）'),
      '15',
    );
    await tester.tap(find.text('餐饮'), warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('视频会员'), findsOneWidget);
    expect(find.textContaining('¥15.00'), findsOneWidget);
  });

  testWidgets('首页到期提醒：一键入账并顺延', (tester) async {
    final provider = RecurringBillsProvider();
    final tx = TransactionProvider();
    final cp = CategoryProvider();
    final bp = BudgetProvider();
    final now = DateTime.now();
    await tester.runAsync(() async {
      final cats = await cp.categories();
      final food = cats.firstWhere((c) => c.name == '餐饮');
      await provider.add(RecurringBill(
        name: '视频会员',
        amountCents: 1500,
        categoryId: food.id!,
        periodType: RecurringBill.periodMonthly,
        periodValue: now.day,
        nextDueDate: now.subtract(const Duration(days: 1)),
      ));
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider.value(value: tx),
          ChangeNotifierProvider.value(value: cp),
          ChangeNotifierProvider.value(value: bp),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('周期账单到期'), findsOneWidget);
    await tester.tap(find.text('一键入账（1 笔）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('入账'));
    await tester.pumpAndSettle();

    // 流水已入账
    final monthKey = FinanceMath.monthKey(now);
    final txs = (await tester.runAsync<List<Transaction>>(
      () => tx.transactionsOfMonth(monthKey),
    )) ??
        const <Transaction>[];
    final expense =
        txs.where((t) => t.type == Transaction.typeExpense).toList();
    expect(expense, hasLength(1));
    expect(expense.first.amountCents, 1500);

    // 顺延到本月到期日（>= 今天）
    final bills = (await tester.runAsync(() => provider.bills())) ??
        const <RecurringBill>[];
    final due = DateTime(
      bills.first.nextDueDate.year,
      bills.first.nextDueDate.month,
      bills.first.nextDueDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    expect(due.isBefore(today), isFalse);

    // 卡片消失
    expect(find.text('周期账单到期'), findsNothing);
  });
}