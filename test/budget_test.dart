import 'package:campus_wallet/core/data/app_database.dart';
import 'package:campus_wallet/core/data/dao.dart';
import 'package:campus_wallet/core/logic/finance_math.dart';
import 'package:campus_wallet/core/models/budget_setting.dart';
import 'package:campus_wallet/core/models/transaction.dart';
import 'package:campus_wallet/core/theme/app_theme.dart';
import 'package:campus_wallet/features/budget/budget_page.dart';
import 'package:campus_wallet/features/budget/progress_tier.dart';
import 'package:campus_wallet/state/budget_provider.dart';
import 'package:campus_wallet/state/category_provider.dart';
import 'package:campus_wallet/state/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    AppDatabase.instance.dbName = 'cw_test_budget.db';
    await AppDatabase.instance.database;
    await Dao.instance.clearAllData();
  });

  setUp(() async {
    await Dao.instance.clearAllData();
  });

  test('progressTierFor 三档与边界', () {
    expect(progressTierFor(0.0), ProgressTier.normal);
    expect(progressTierFor(0.7999), ProgressTier.normal);
    expect(progressTierFor(0.8), ProgressTier.warn);
    expect(progressTierFor(0.999), ProgressTier.warn);
    expect(progressTierFor(1.0), ProgressTier.over);
    expect(progressTierFor(1.5), ProgressTier.over);
  });

  test('R7：月度预算总额的覆盖与恢复默认', () async {
    final bp = BudgetProvider();
    await bp.saveSetting(const BudgetSetting(allowanceAmountCents: 150000));
    expect(bp.effectiveMonthlyBudgetCents, 150000);

    await bp.saveSetting(
      bp.setting.copyWith(monthlyBudgetCents: 200000),
    );
    expect(bp.effectiveMonthlyBudgetCents, 200000);

    await bp.saveSetting(bp.setting.copyWith(clearMonthlyBudget: true));
    expect(bp.effectiveMonthlyBudgetCents, 150000);
  });

  testWidgets('配额超支 → 进度条为超支色', (tester) async {
    final bp = BudgetProvider();
    final tp = TransactionProvider();
    final cp = CategoryProvider();
    final now = DateTime.now();
    final monthKey = FinanceMath.monthKey(now);
    await tester.runAsync(() async {
      final cats = await cp.categories();
      final food = cats.firstWhere((c) => c.name == '餐饮');
      await tp.add(Transaction(
        type: Transaction.typeExpense,
        amountCents: 50000,
        categoryId: food.id!,
        occurredAt: now,
        createdAt: now,
      ));
      await bp.setCategoryBudget(
        categoryId: food.id!,
        month: monthKey,
        limitCents: 40000,
      );
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: bp),
          ChangeNotifierProvider.value(value: tp),
          ChangeNotifierProvider.value(value: cp),
        ],
        child: const MaterialApp(home: BudgetPage()),
      ),
    );
    await tester.pumpAndSettle();

    final bars = tester.widgetList<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bars.any((b) => b.color == AppColors.over), isTrue);
  });

  test('配额设为 0 → 删除配额', () async {
    final bp = BudgetProvider();
    final cp = CategoryProvider();
    final cats = await cp.categories();
    final food = cats.firstWhere((c) => c.name == '餐饮');
    final monthKey = FinanceMath.monthKey(DateTime.now());

    await bp.setCategoryBudget(
      categoryId: food.id!,
      month: monthKey,
      limitCents: 30000,
    );
    expect(await bp.budgetsOfMonth(monthKey), hasLength(1));

    await bp.setCategoryBudget(
      categoryId: food.id!,
      month: monthKey,
      limitCents: 0,
    );
    expect(await bp.budgetsOfMonth(monthKey), isEmpty);
  });
}