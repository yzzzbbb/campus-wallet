import 'package:campus_wallet/core/data/app_database.dart';
import 'package:campus_wallet/core/data/dao.dart';
import 'package:campus_wallet/core/models/category.dart';
import 'package:campus_wallet/core/models/transaction.dart';
import 'package:campus_wallet/features/settings/category_manage_page.dart';
import 'package:campus_wallet/state/category_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    AppDatabase.instance.dbName = 'cw_test_catmgmt.db';
    // 删掉上次运行残留的库，保证内置分类是初始状态
    final path = p.join(
      await databaseFactory.getDatabasesPath(),
      'cw_test_catmgmt.db',
    );
    if (await databaseFactory.databaseExists(path)) {
      await databaseFactory.deleteDatabase(path);
    }
    await AppDatabase.instance.database;
  });

  setUp(() async {
    await Dao.instance.clearAllData();
    await Dao.instance.deleteCustomCategories();
  });

  Future<void> pumpPage(WidgetTester tester, CategoryProvider cp) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: cp)],
        child: const MaterialApp(home: CategoryManagePage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('新增自定义分类并显示', (tester) async {
    final cp = CategoryProvider();
    await pumpPage(tester, cp);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '奶茶');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 新分类排最后，滚动到可见
    await tester.dragUntilVisible(
      find.text('奶茶'),
      find.byType(ListView).first,
      const Offset(0, -100),
    );
    await tester.pump();
    expect(find.text('奶茶'), findsOneWidget);
    final cats = (await tester.runAsync(() => cp.categories())) ??
        const <Category>[];
    expect(cats.any((c) => c.name == '奶茶'), isTrue);
  });

  testWidgets('内置分类可改名但无删除按钮', (tester) async {
    final cp = CategoryProvider();
    await pumpPage(tester, cp);

    // 内置分类显示（内置）后缀，且没有删除按钮
    expect(find.text('餐饮（内置）'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    // 改名
    await tester.tap(find.text('餐饮（内置）'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '干饭');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('干饭（内置）'), findsOneWidget);
    final cats = (await tester.runAsync(() => cp.categories())) ??
        const <Category>[];
    expect(cats.any((c) => c.name == '干饭' && c.builtin), isTrue);
  });

  testWidgets('删除自定义分类', (tester) async {
    final cp = CategoryProvider();
    await tester.runAsync(() async {
      await cp.addCategory(const Category(
        name: '奶茶',
        type: Category.typeExpense,
        icon: 'more_horiz',
        color: 0xFF42A5F5,
        sort: 99,
      ));
    });
    await pumpPage(tester, cp);
    await tester.dragUntilVisible(
      find.text('奶茶'),
      find.byType(ListView).first,
      const Offset(0, -100),
    );
    await tester.pump();
    expect(find.text('奶茶'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('奶茶'), findsNothing);
  });

  testWidgets('有流水的分类禁止删除', (tester) async {
    final cp = CategoryProvider();
    int? catId;
    await tester.runAsync(() async {
      await cp.addCategory(const Category(
        name: '奶茶',
        type: Category.typeExpense,
        icon: 'more_horiz',
        color: 0xFF42A5F5,
        sort: 99,
      ));
      final cats = await cp.categories();
      catId = cats.firstWhere((c) => c.name == '奶茶').id;
      final now = DateTime.now();
      await Dao.instance.insertTransaction(Transaction(
        type: Transaction.typeExpense,
        amountCents: 1500,
        categoryId: catId!,
        occurredAt: now,
        createdAt: now,
      ));
    });
    await pumpPage(tester, cp);
    await tester.dragUntilVisible(
      find.text('奶茶'),
      find.byType(ListView).first,
      const Offset(0, -100),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('该分类已有流水，无法删除'), findsOneWidget);
    final cats = (await tester.runAsync(() => cp.categories())) ??
        const <Category>[];
    expect(cats.any((c) => c.id == catId), isTrue);
  });
}