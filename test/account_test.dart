import 'package:campus_wallet/core/data/app_database.dart';
import 'package:campus_wallet/core/data/dao.dart';
import 'package:campus_wallet/core/models/account.dart';
import 'package:campus_wallet/core/models/transaction.dart';
import 'package:campus_wallet/features/settings/account_manage_page.dart';
import 'package:campus_wallet/state/account_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    AppDatabase.instance.dbName = 'cw_test_account.db';
    await AppDatabase.instance.database;
  });

  setUp(() async {
    await Dao.instance.clearAllData();
    await Dao.instance.clearRecurringBills();
    await Dao.instance.deleteCustomAccounts();
  });

  test('内置账户种子：现金/饭卡/银行卡', () async {
    final accounts = await Dao.instance.accounts();
    final names = accounts.map((a) => a.name).toList();
    expect(names, containsAll(['现金', '饭卡', '银行卡']));
    expect(accounts.every((a) => a.builtin), isTrue);
  });

  test('账户 CRUD 与 Account 模型往返', () async {
    final dao = Dao.instance;
    final id = await dao.insertAccount(Account(
      name: '支付宝',
      icon: 'qr_code',
      color: 0xFF1565C0,
      sort: 99,
    ));
    var accounts = await dao.accounts();
    final added = accounts.firstWhere((a) => a.id == id);
    expect(added.name, '支付宝');
    expect(added.icon, 'qr_code');

    await dao.updateAccount(added.copyWith(name: '微信'));
    accounts = await dao.accounts();
    expect(accounts.any((a) => a.name == '微信'), isTrue);

    await dao.deleteAccount(id);
    accounts = await dao.accounts();
    expect(accounts.any((a) => a.id == id), isFalse);
  });

  test('流水带账户往返', () async {
    final dao = Dao.instance;
    final accounts = await dao.accounts();
    final cash = accounts.firstWhere((a) => a.name == '现金');
    final cats = await dao.categories();
    final food = cats.firstWhere((c) => c.name == '餐饮');
    final now = DateTime.now();

    await dao.insertTransaction(Transaction(
      type: Transaction.typeExpense,
      amountCents: 3000,
      categoryId: food.id!,
      accountId: cash.id,
      occurredAt: now,
      createdAt: now,
    ));

    final txs = await dao.allTransactions();
    expect(txs, hasLength(1));
    expect(txs.first.accountId, cash.id);

    // 无账户流水 accountId 为 null
    await dao.insertTransaction(Transaction(
      type: Transaction.typeExpense,
      amountCents: 1000,
      categoryId: food.id!,
      occurredAt: now,
      createdAt: now,
    ));
    final txs2 = await dao.allTransactions();
    expect(txs2.where((t) => t.accountId == null), hasLength(1));
  });

  test('有流水的账户删除保护（transactionCount）', () async {
    final dao = Dao.instance;
    final accounts = await dao.accounts();
    final cash = accounts.firstWhere((a) => a.name == '现金');
    final cats = await dao.categories();
    final food = cats.firstWhere((c) => c.name == '餐饮');
    final now = DateTime.now();
    await dao.insertTransaction(Transaction(
      type: Transaction.typeExpense,
      amountCents: 100,
      categoryId: food.id!,
      accountId: cash.id,
      occurredAt: now,
      createdAt: now,
    ));
    expect(await dao.transactionCountByAccount(cash.id!), 1);
  });

  testWidgets('账户管理页展示内置账户', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AccountProvider(),
        child: const MaterialApp(home: AccountManagePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('现金'), findsOneWidget);
    expect(find.text('饭卡'), findsOneWidget);
    expect(find.text('银行卡'), findsOneWidget);
    expect(find.text('新增账户'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}