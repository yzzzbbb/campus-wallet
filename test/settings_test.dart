import 'package:campus_wallet/core/data/app_database.dart';
import 'package:campus_wallet/core/data/dao.dart';
import 'package:campus_wallet/core/models/transaction.dart';
import 'package:campus_wallet/state/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    AppDatabase.instance.dbName = 'cw_test_settings.db';
    await AppDatabase.instance.database;
  });

  setUp(() async {
    await Dao.instance.clearAllData();
  });

  test('themeMode 默认跟随系统，可保存并恢复', () async {
    final sp = SettingsProvider();
    await sp.load();
    expect(sp.themeMode, ThemeMode.system);

    await sp.setThemeMode(ThemeMode.dark);
    final sp2 = SettingsProvider();
    await sp2.load();
    expect(sp2.themeMode, ThemeMode.dark);

    await sp2.setThemeMode(ThemeMode.light);
    final sp3 = SettingsProvider();
    await sp3.load();
    expect(sp3.themeMode, ThemeMode.light);
  });

  test('clearAllData 清空流水与设置，保留分类', () async {
    final dao = Dao.instance;
    final cats = await dao.categories();
    final food = cats.firstWhere((c) => c.name == '餐饮');
    final now = DateTime.now();
    await dao.insertTransaction(Transaction(
      type: Transaction.typeExpense,
      amountCents: 100,
      categoryId: food.id!,
      occurredAt: now,
      createdAt: now,
    ));
    await dao.setSetting('theme_mode', 'dark');
    expect((await dao.allTransactions()).length, 1);

    await dao.clearAllData();
    expect(await dao.allTransactions(), isEmpty);
    expect(await dao.getSetting('theme_mode'), isNull);
    expect((await dao.categories()).length, cats.length);
  });
}