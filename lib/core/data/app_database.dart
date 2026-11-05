import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// sqflite 单例：建库、建表、内置分类种子。
/// 表结构与种子数据是契约，禁止修改。
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  /// 数据库文件名（测试可覆盖为独立文件，避免并行测试互相锁库）
  String dbName = 'campus_wallet.db';

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = p.join(await getDatabasesPath(), dbName);
    _db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT 'more_horiz',
        color INTEGER NOT NULL DEFAULT 0xFF4CAF50,
        sort INTEGER NOT NULL DEFAULT 0,
        builtin INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        occurred_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE category_budgets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        month TEXT NOT NULL,
        limit_cents INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX idx_cat_budget ON category_budgets(category_id, month)',
    );
    await db.execute('''
      CREATE TABLE recurring_bills(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        period_type TEXT NOT NULL,
        period_value INTEGER NOT NULL,
        next_due_date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');

    const seeds = <Map<String, Object>>[
      {'name': '餐饮', 'type': 'expense', 'icon': 'restaurant', 'color': 0xFFFF7043, 'sort': 1},
      {'name': '日用', 'type': 'expense', 'icon': 'shopping_basket', 'color': 0xFF42A5F5, 'sort': 2},
      {'name': '学习', 'type': 'expense', 'icon': 'school', 'color': 0xFF7E57C2, 'sort': 3},
      {'name': '交通', 'type': 'expense', 'icon': 'directions_bus', 'color': 0xFF26A69A, 'sort': 4},
      {'name': '娱乐', 'type': 'expense', 'icon': 'movie', 'color': 0xFFEC407A, 'sort': 5},
      {'name': '服饰', 'type': 'expense', 'icon': 'checkroom', 'color': 0xFF8D6E63, 'sort': 6},
      {'name': '医疗', 'type': 'expense', 'icon': 'local_hospital', 'color': 0xFFEF5350, 'sort': 7},
      {'name': '人情', 'type': 'expense', 'icon': 'favorite', 'color': 0xFFAB47BC, 'sort': 8},
      {'name': '其他', 'type': 'expense', 'icon': 'more_horiz', 'color': 0xFF78909C, 'sort': 9},
      {'name': '生活费', 'type': 'income', 'icon': 'payments', 'color': 0xFF66BB6A, 'sort': 1},
      {'name': '奖学金', 'type': 'income', 'icon': 'school', 'color': 0xFF5C6BC0, 'sort': 2},
      {'name': '兼职', 'type': 'income', 'icon': 'work', 'color': 0xFFFFA726, 'sort': 3},
      {'name': '红包', 'type': 'income', 'icon': 'redeem', 'color': 0xFFEF5350, 'sort': 4},
      {'name': '其他', 'type': 'income', 'icon': 'more_horiz', 'color': 0xFF78909C, 'sort': 5},
    ];
    for (final c in seeds) {
      await db.insert('categories', {...c, 'builtin': 1});
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE recurring_bills(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          amount_cents INTEGER NOT NULL,
          category_id INTEGER NOT NULL,
          period_type TEXT NOT NULL,
          period_value INTEGER NOT NULL,
          next_due_date TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT ''
        )
      ''');
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}