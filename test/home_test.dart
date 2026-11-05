import 'package:campus_wallet/core/data/app_database.dart';
import 'package:campus_wallet/core/data/dao.dart';
import 'package:campus_wallet/core/logic/finance_math.dart';
import 'package:campus_wallet/core/models/budget_setting.dart';
import 'package:campus_wallet/core/models/transaction.dart';
import 'package:campus_wallet/features/home/home_page.dart';
import 'package:campus_wallet/state/budget_provider.dart';
import 'package:campus_wallet/state/category_provider.dart';
import 'package:campus_wallet/state/recurring_bills_provider.dart';
import 'package:campus_wallet/state/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    // 在真实事件循环中一次性打开数据库，避免 FakeAsync 跨区打开留下锁
    AppDatabase.instance.dbName = 'cw_test_home.db';
    await AppDatabase.instance.database;
    await Dao.instance.clearAllData();
  });

  setUp(() async {
    await Dao.instance.clearAllData();
  });

  Future<void> pumpHome(
    WidgetTester tester,
    BudgetProvider bp,
    TransactionProvider tp,
    CategoryProvider cp,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: tp),
          ChangeNotifierProvider.value(value: cp),
          ChangeNotifierProvider.value(value: bp),
          ChangeNotifierProvider.value(value: RecurringBillsProvider()),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('倒计时卡片：今天发生活费 + 剩余正确', (tester) async {
    final bp = BudgetProvider();
    final tp = TransactionProvider();
    final cp = CategoryProvider();
    final today = DateTime.now();
    await tester.runAsync(() async {
      await bp.saveSetting(BudgetSetting(
        allowanceAmountCents: 150000,
        periodType: BudgetSetting.periodMonthly,
        payDay: today.day,
      ));
      final cats = await cp.categories();
      final food = cats.firstWhere((c) => c.name == '餐饮');
      await tp.add(Transaction(
        type: Transaction.typeExpense,
        amountCents: 30000,
        categoryId: food.id!,
        occurredAt: today,
        createdAt: today,
      ));
    });
    await pumpHome(tester, bp, tp, cp);

    expect(find.text('今天发生活费！'), findsOneWidget);
    expect(find.textContaining('¥1,200.00'), findsWidgets);
  });

  testWidgets('倒计时卡片：每N天周期 + 日均可用', (tester) async {
    final bp = BudgetProvider();
    final tp = TransactionProvider();
    final cp = CategoryProvider();
    final today = DateTime.now();
    await tester.runAsync(() async {
      await bp.saveSetting(BudgetSetting(
        allowanceAmountCents: 100000,
        periodType: BudgetSetting.periodEveryNDays,
        everyNDays: 7,
        lastPayDate: today,
      ));
      final cats = await cp.categories();
      final food = cats.firstWhere((c) => c.name == '餐饮');
      await tp.add(Transaction(
        type: Transaction.typeExpense,
        amountCents: 30000,
        categoryId: food.id!,
        occurredAt: today,
        createdAt: today,
      ));
    });
    await pumpHome(tester, bp, tp, cp);

    expect(find.text('还有 7 天'), findsOneWidget);
    expect(find.textContaining('¥100.00'), findsWidgets);
  });

  testWidgets('未配置生活费 → 引导卡片', (tester) async {
    final bp = BudgetProvider();
    final tp = TransactionProvider();
    final cp = CategoryProvider();
    await pumpHome(tester, bp, tp, cp);

    expect(find.textContaining('设置'), findsWidgets);
    expect(find.text('开始规划你的生活费'), findsOneWidget);
  });

  testWidgets('超支显示已超支金额', (tester) async {
    final bp = BudgetProvider();
    final tp = TransactionProvider();
    final cp = CategoryProvider();
    final today = DateTime.now();
    await tester.runAsync(() async {
      await bp.saveSetting(BudgetSetting(
        allowanceAmountCents: 150000,
        periodType: BudgetSetting.periodMonthly,
        payDay: today.day,
      ));
      final cats = await cp.categories();
      final food = cats.firstWhere((c) => c.name == '餐饮');
      await tp.add(Transaction(
        type: Transaction.typeExpense,
        amountCents: 200000,
        categoryId: food.id!,
        occurredAt: today,
        createdAt: today,
      ));
    });
    await pumpHome(tester, bp, tp, cp);

    expect(find.textContaining('已超支'), findsOneWidget);
    expect(find.textContaining('¥500.00'), findsWidgets);
  });

  testWidgets('收到生活费 → 记收入并重置倒计时', (tester) async {
    final bp = BudgetProvider();
    final tp = TransactionProvider();
    final cp = CategoryProvider();
    final today = DateTime.now();
    await tester.runAsync(() async {
      await bp.saveSetting(BudgetSetting(
        allowanceAmountCents: 150000,
        periodType: BudgetSetting.periodMonthly,
        payDay: today.day,
      ));
    });
    await pumpHome(tester, bp, tp, cp);

    await tester.tap(find.text('收到生活费'));
    await tester.pumpAndSettle();

    final monthKey = FinanceMath.monthKey(DateTime.now());
    final txs = (await tester.runAsync<List<Transaction>>(
      () => tp.transactionsOfMonth(monthKey),
    )) ??
        const <Transaction>[];
    final income =
        txs.where((t) => t.type == Transaction.typeIncome).toList();
    expect(income, hasLength(1));
    expect(income.first.amountCents, 150000);
    expect(bp.setting.lastPayDate, isNotNull);
  });
}