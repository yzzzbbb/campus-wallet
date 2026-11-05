import 'package:campus_wallet/core/data/app_database.dart';
import 'package:campus_wallet/core/data/dao.dart';
import 'package:campus_wallet/core/logic/finance_math.dart';
import 'package:campus_wallet/core/models/transaction.dart';
import 'package:campus_wallet/features/transaction/transaction_edit_page.dart';
import 'package:campus_wallet/features/transaction/transaction_list_page.dart';
import 'package:campus_wallet/state/account_provider.dart';
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
    AppDatabase.instance.dbName = 'cw_test_transaction.db';
    await AppDatabase.instance.database;
    await Dao.instance.clearAllData();
  });

  setUp(() async {
    await Dao.instance.clearAllData();
  });

  Future<void> pumpApp(
    WidgetTester tester,
    TransactionProvider tp,
    CategoryProvider cp,
    Widget home,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: tp),
          ChangeNotifierProvider.value(value: cp),
          ChangeNotifierProvider(create: (_) => AccountProvider()),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('列表：两个日分组 + 当日支出合计', (tester) async {
    final tp = TransactionProvider();
    final cp = CategoryProvider();
    final now = DateTime.now();
    // 保证第二天与今天同月（跨月边界安全）
    final second = now.day == 1
        ? now.add(const Duration(days: 1))
        : now.subtract(const Duration(days: 1));
    await tester.runAsync(() async {
      final cats = await cp.categories();
      final food = cats.firstWhere((c) => c.name == '餐饮');
      final bus = cats.firstWhere((c) => c.name == '交通');
      final gift = cats.firstWhere((c) => c.name == '红包');
      await tp.add(Transaction(
        type: Transaction.typeExpense,
        amountCents: 1200,
        categoryId: food.id!,
        occurredAt: now,
        createdAt: now,
      ));
      await tp.add(Transaction(
        type: Transaction.typeExpense,
        amountCents: 2500,
        categoryId: bus.id!,
        occurredAt: now,
        createdAt: now,
      ));
      await tp.add(Transaction(
        type: Transaction.typeIncome,
        amountCents: 5000,
        categoryId: gift.id!,
        occurredAt: second,
        createdAt: second,
      ));
    });

    await pumpApp(tester, tp, cp, const TransactionListPage());

    expect(
      find.textContaining('${now.month}月${now.day}日'),
      findsWidgets,
    );
    expect(
      find.textContaining('${second.month}月${second.day}日'),
      findsWidgets,
    );
    expect(find.textContaining('¥37.00'), findsOneWidget);
  });

  testWidgets('长按删除流水', (tester) async {
    final tp = TransactionProvider();
    final cp = CategoryProvider();
    final now = DateTime.now();
    await tester.runAsync(() async {
      final cats = await cp.categories();
      final food = cats.firstWhere((c) => c.name == '餐饮');
      final bus = cats.firstWhere((c) => c.name == '交通');
      await tp.add(Transaction(
        type: Transaction.typeExpense,
        amountCents: 1200,
        categoryId: food.id!,
        occurredAt: now,
        createdAt: now,
      ));
      await tp.add(Transaction(
        type: Transaction.typeExpense,
        amountCents: 2500,
        categoryId: bus.id!,
        occurredAt: now,
        createdAt: now,
      ));
    });

    await pumpApp(tester, tp, cp, const TransactionListPage());

    await tester.longPress(find.text('餐饮'));
    await tester.pumpAndSettle();
    expect(find.text('删除这条流水？'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('餐饮'), findsNothing);
    final monthKey = FinanceMath.monthKey(now);
    final txs = (await tester.runAsync<List<Transaction>>(
      () => tp.transactionsOfMonth(monthKey),
    )) ??
        const <Transaction>[];
    expect(txs, hasLength(1));
  });

  testWidgets('点击流水进入编辑并改金额', (tester) async {
    final tp = TransactionProvider();
    final cp = CategoryProvider();
    final now = DateTime.now();
    await tester.runAsync(() async {
      final cats = await cp.categories();
      final food = cats.firstWhere((c) => c.name == '餐饮');
      await tp.add(Transaction(
        type: Transaction.typeExpense,
        amountCents: 1200,
        categoryId: food.id!,
        occurredAt: now,
        createdAt: now,
      ));
    });

    await pumpApp(tester, tp, cp, const TransactionListPage());

    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionEditPage), findsOneWidget);

    // 清空 '12.00'（5 个字符）
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byIcon(Icons.backspace_outlined));
    }
    await tester.tap(find.text('5'));
    await tester.tap(find.text('0'));
    await tester.pump();
    await tester.tap(find.text('保存').first);
    await tester.pumpAndSettle();

    expect(find.byType(TransactionEditPage), findsNothing);
    expect(find.textContaining('¥50.00'), findsWidgets);
  });

  testWidgets('空月显示暂无流水', (tester) async {
    final tp = TransactionProvider();
    final cp = CategoryProvider();
    await pumpApp(tester, tp, cp, const TransactionListPage());
    expect(find.text('本月暂无流水'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('本月暂无流水'), findsOneWidget);
  });

  testWidgets('编辑页输入 12.5 保存为 1250 分', (tester) async {
    final tp = TransactionProvider();
    final cp = CategoryProvider();
    await pumpApp(tester, tp, cp, const TransactionEditPage());

    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('.'));
    await tester.tap(find.text('5'));
    await tester.pump();
    expect(find.text('¥ 12.5'), findsOneWidget);

    // 分类网格在页面下方，先滚动到可见
    await tester.dragUntilVisible(
      find.text('餐饮'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    await tester.pump();
    await tester.tap(find.text('餐饮'));
    await tester.pump();
    await tester.tap(find.text('保存').first);
    await tester.pumpAndSettle();

    final monthKey = FinanceMath.monthKey(DateTime.now());
    final txs = (await tester.runAsync<List<Transaction>>(
      () => tp.transactionsOfMonth(monthKey),
    )) ??
        const <Transaction>[];
    expect(txs, hasLength(1));
    expect(txs.first.amountCents, 1250);
    expect(txs.first.type, Transaction.typeExpense);
  });
}