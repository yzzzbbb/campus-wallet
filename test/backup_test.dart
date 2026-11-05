import 'package:campus_wallet/core/data/app_database.dart';
import 'package:campus_wallet/core/data/dao.dart';
import 'package:campus_wallet/core/models/account.dart';
import 'package:campus_wallet/core/models/category.dart';
import 'package:campus_wallet/core/models/recurring_bill.dart';
import 'package:campus_wallet/core/models/transaction.dart';
import 'package:campus_wallet/features/settings/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    AppDatabase.instance.dbName = 'cw_test_backup.db';
    final path = p.join(
      await databaseFactory.getDatabasesPath(),
      'cw_test_backup.db',
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
    await Dao.instance.deleteCustomAccounts();
  });

  Future<void> seedData() async {
    final dao = Dao.instance;
    final now = DateTime.now();
    await dao.insertCategory(const Category(
      name: '奶茶',
      type: Category.typeExpense,
      icon: 'restaurant',
      color: 0xFF42A5F5,
      sort: 99,
    ));
    final cats = await dao.categories();
    final food = cats.firstWhere((c) => c.name == '餐饮');
    final milkTea = cats.firstWhere((c) => c.name == '奶茶');
    await dao.insertTransaction(Transaction(
      type: Transaction.typeExpense,
      amountCents: 1500,
      categoryId: milkTea.id!,
      note: '测试流水',
      occurredAt: now,
      createdAt: now,
    ));
    await dao.setSetting('theme_mode', 'dark');
    await dao.setCategoryBudget(
      categoryId: food.id!,
      month: '2026-11',
      limitCents: 50000,
    );
    await dao.insertRecurringBill(RecurringBill(
      name: '视频会员',
      amountCents: 1500,
      categoryId: food.id!,
      periodType: RecurringBill.periodMonthly,
      periodValue: 15,
      nextDueDate: DateTime(2026, 11, 15),
    ));
    await dao.insertAccount(Account(
      name: '支付宝',
      icon: 'qr_code',
      color: 0xFF1565C0,
      sort: 99,
    ));
  }

  test('buildBackupJson 包含全部数据', () async {
    await seedData();
    final json = await BackupService.buildBackupJson();

    expect(json.contains('"app": "campus_wallet"'), isTrue);
    expect(json.contains('奶茶'), isTrue);
    expect(json.contains('测试流水'), isTrue);
    expect(json.contains('"theme_mode": "dark"'), isTrue);
    expect(json.contains('"limit_cents": 50000'), isTrue);
    expect(json.contains('视频会员'), isTrue);
    expect(json.contains('支付宝'), isTrue);
  });

  test('restoreFromJson 完整回滚数据', () async {
    await seedData();
    final json = await BackupService.buildBackupJson();

    // 清空后恢复
    await Dao.instance.clearAllData();
    await Dao.instance.clearRecurringBills();
    await Dao.instance.deleteCustomCategories();
    await Dao.instance.deleteCustomAccounts();
    await BackupService.restoreFromJson(json);

    final dao = Dao.instance;
    final cats = await dao.categories();
    expect(cats.any((c) => c.name == '奶茶'), isTrue);
    expect(cats.any((c) => c.name == '餐饮'), isTrue);
    final txs = await dao.allTransactions();
    expect(txs, hasLength(1));
    expect(txs.first.note, '测试流水');
    expect(await dao.getSetting('theme_mode'), 'dark');
    final budgets = await dao.allCategoryBudgets();
    expect(budgets, hasLength(1));
    expect(budgets.first.limitCents, 50000);
    final bills = await dao.allRecurringBills();
    expect(bills, hasLength(1));
    expect(bills.first.name, '视频会员');
    final accounts = await dao.allAccounts();
    expect(accounts.any((a) => a.name == '支付宝'), isTrue);
  });

  test('恢复坏 JSON 抛错且不破坏现有数据', () async {
    await seedData();

    await expectLater(
      () => BackupService.restoreFromJson('{not-valid-json'),
      throwsFormatException,
    );
    final txs = await Dao.instance.allTransactions();
    expect(txs, hasLength(1));
  });

  test('非本应用或版本不符的备份被拒绝', () async {
    await expectLater(
      () => BackupService.restoreFromJson(
        '{"app": "other_app", "version": 1, "categories": [], '
        '"transactions": [], "settings": {}, "category_budgets": []}',
      ),
      throwsFormatException,
    );

    await expectLater(
      () => BackupService.restoreFromJson(
        '{"app": "campus_wallet", "version": 99, "categories": [], '
        '"transactions": [], "settings": {}, "category_budgets": []}',
      ),
      throwsFormatException,
    );
  });
}