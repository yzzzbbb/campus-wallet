import 'package:campus_wallet/core/data/app_database.dart';
import 'package:campus_wallet/core/data/dao.dart';
import 'package:campus_wallet/main_shell.dart';
import 'package:campus_wallet/state/budget_provider.dart';
import 'package:campus_wallet/state/category_provider.dart';
import 'package:campus_wallet/state/settings_provider.dart';
import 'package:campus_wallet/state/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    AppDatabase.instance.dbName = 'cw_test_shell.db';
    await AppDatabase.instance.database;
  });

  setUp(() async {
    await Dao.instance.clearAllData();
  });

  testWidgets('MainShell 四个 Tab 均可渲染并切换', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TransactionProvider()),
          ChangeNotifierProvider(create: (_) => CategoryProvider()),
          ChangeNotifierProvider(create: (_) => BudgetProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await tester.pumpAndSettle();

    // 首页（未配置引导）
    expect(find.text('开始规划你的生活费'), findsOneWidget);
    for (final label in ['首页', '流水', '统计', '我的']) {
      expect(find.text(label), findsOneWidget);
    }

    // 流水
    await tester.tap(find.text('流水'));
    await tester.pumpAndSettle();
    expect(find.text('本月暂无流水'), findsOneWidget);

    // 统计
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.text('本月还没有支出'), findsOneWidget);

    // 我的
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('深色模式'), findsOneWidget);
  });
}