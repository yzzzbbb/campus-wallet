import 'package:campus_wallet/core/data/app_database.dart';
import 'package:campus_wallet/core/data/dao.dart';
import 'package:campus_wallet/core/logic/finance_math.dart';
import 'package:campus_wallet/core/models/budget_setting.dart';
import 'package:campus_wallet/core/models/category.dart';
import 'package:campus_wallet/core/models/category_budget.dart';
import 'package:campus_wallet/core/models/transaction.dart';
import 'package:campus_wallet/features/stats/stats_data.dart';
import 'package:campus_wallet/features/stats/stats_page.dart';
import 'package:campus_wallet/state/budget_provider.dart';
import 'package:campus_wallet/state/category_provider.dart';
import 'package:campus_wallet/state/transaction_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

const _categories = [
  Category(
    id: 1,
    name: '餐饮',
    type: Category.typeExpense,
    icon: 'restaurant',
    color: 0xFFFF7043,
    sort: 1,
  ),
  Category(
    id: 2,
    name: '日用',
    type: Category.typeExpense,
    icon: 'shopping_basket',
    color: 0xFF42A5F5,
    sort: 2,
  ),
  Category(
    id: 3,
    name: '学习',
    type: Category.typeExpense,
    icon: 'school',
    color: 0xFF7E57C2,
    sort: 3,
  ),
];

const _abcCategories = [
  Category(
    id: 1,
    name: 'A',
    type: Category.typeExpense,
    icon: 'more_horiz',
    color: 0xFF111111,
    sort: 1,
  ),
  Category(
    id: 2,
    name: 'B',
    type: Category.typeExpense,
    icon: 'more_horiz',
    color: 0xFF222222,
    sort: 2,
  ),
  Category(
    id: 3,
    name: 'C',
    type: Category.typeExpense,
    icon: 'more_horiz',
    color: 0xFF333333,
    sort: 3,
  ),
];

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    AppDatabase.instance.dbName = 'cw_test_stats.db';
    await AppDatabase.instance.database;
    await Dao.instance.clearAllData();
  });

  setUp(() async {
    await Dao.instance.clearAllData();
  });

  group('stats_data 纯函数', () {
    test('buildPieEntries：3 分类支出 100/200/100，合计 400 且降序', () {
      final entries = buildPieEntries(
        byCategory: {1: 100, 2: 200, 3: 100},
        categories: _categories,
      );

      expect(entries, hasLength(3));
      expect(entries.fold<int>(0, (sum, e) => sum + e.cents), 400);
      expect(entries.first.cents, 200);
      for (var i = 0; i + 1 < entries.length; i++) {
        expect(entries[i].cents >= entries[i + 1].cents, isTrue);
      }
    });

    test('buildPieEntries：找不到分类的条目跳过', () {
      final entries = buildPieEntries(
        byCategory: {1: 100, 999: 50},
        categories: _categories,
      );

      expect(entries, hasLength(1));
      expect(entries.single.name, '餐饮');
      expect(entries.single.cents, 100);
    });

    test('buildOverrunTop3：配额 A:100 B:200 C:50，支出 A:150 B:100 C:60', () {
      final result = buildOverrunTop3(
        byCategory: {1: 150, 2: 100, 3: 60},
        categories: _abcCategories,
        budgets: const [
          CategoryBudget(categoryId: 1, month: '2026-11', limitCents: 100),
          CategoryBudget(categoryId: 2, month: '2026-11', limitCents: 200),
          CategoryBudget(categoryId: 3, month: '2026-11', limitCents: 50),
        ],
      );

      expect(result, hasLength(2));
      expect(result[0].name, 'A');
      expect(result[0].overspentCents, 50);
      expect(result[1].name, 'C');
      expect(result[1].overspentCents, 10);
    });

    test('buildOverrunTop3：最多返回 3 条', () {
      final result = buildOverrunTop3(
        byCategory: {1: 200, 2: 200, 3: 200},
        categories: _abcCategories,
        budgets: const [
          CategoryBudget(categoryId: 1, month: '2026-11', limitCents: 100),
          CategoryBudget(categoryId: 2, month: '2026-11', limitCents: 100),
          CategoryBudget(categoryId: 3, month: '2026-11', limitCents: 100),
          CategoryBudget(categoryId: 4, month: '2026-11', limitCents: 100),
        ],
      );

      expect(result, hasLength(3));
    });
  });

  group('StatsPage widget', () {
    testWidgets('当前月有数据时渲染饼图与复盘卡片', (tester) async {
      final transactionProvider = TransactionProvider();
      final categoryProvider = CategoryProvider();
      final budgetProvider = BudgetProvider();

      final now = DateTime.now();
      final monthKey = FinanceMath.monthKey(now);
      final occurredAt = DateTime(now.year, now.month, 1, 12);

      await tester.runAsync(() async {
        final categories = await categoryProvider.categories();
        final expenseCategories =
            categories.where((c) => c.isExpense).toList();
        final incomeCategory = categories.firstWhere((c) => !c.isExpense);

        await transactionProvider.add(Transaction(
          type: Transaction.typeExpense,
          amountCents: 15000,
          categoryId: expenseCategories[0].id!,
          note: '午餐',
          occurredAt: occurredAt,
          createdAt: occurredAt,
        ));
        await transactionProvider.add(Transaction(
          type: Transaction.typeExpense,
          amountCents: 5000,
          categoryId: expenseCategories[1].id!,
          note: '纸巾',
          occurredAt: occurredAt,
          createdAt: occurredAt,
        ));
        await transactionProvider.add(Transaction(
          type: Transaction.typeIncome,
          amountCents: 200000,
          categoryId: incomeCategory.id!,
          note: '生活费',
          occurredAt: occurredAt,
          createdAt: occurredAt,
        ));

        await budgetProvider.saveSetting(
          const BudgetSetting(allowanceAmountCents: 100000),
        );
        await budgetProvider.setCategoryBudget(
          categoryId: expenseCategories[0].id!,
          month: monthKey,
          limitCents: 10000,
        );
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: transactionProvider),
            ChangeNotifierProvider.value(value: categoryProvider),
            ChangeNotifierProvider.value(value: budgetProvider),
          ],
          child: MaterialApp(home: StatsPage(monthKey: monthKey)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PieChart), findsOneWidget);
      // 复盘卡片在列表下方，先滚动到可见再断言
      await tester.scrollUntilVisible(find.text('本月复盘'), 300);
      expect(find.textContaining('复盘'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('当前月无支出时显示占位文案且不渲染空饼图', (tester) async {
      final now = DateTime.now();
      final monthKey = FinanceMath.monthKey(now);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => TransactionProvider()),
            ChangeNotifierProvider(create: (_) => CategoryProvider()),
            ChangeNotifierProvider(create: (_) => BudgetProvider()),
          ],
          child: MaterialApp(home: StatsPage(monthKey: monthKey)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('本月还没有支出'), findsOneWidget);
      expect(find.byType(PieChart), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}