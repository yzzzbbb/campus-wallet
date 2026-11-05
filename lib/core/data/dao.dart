import 'package:sqflite/sqflite.dart' hide Transaction;

import '../models/category.dart';
import '../models/category_budget.dart';
import '../models/recurring_bill.dart';
import '../models/transaction.dart';
import 'app_database.dart';

/// 数据访问层（契约：禁止改公开方法签名）
class Dao {
  Dao._();

  static final Dao instance = Dao._();

  Future<Database> get _db => AppDatabase.instance.database;

  // ---------- categories ----------

  Future<List<Category>> categories() async {
    final rows = await (await _db).query(
      'categories',
      orderBy: 'type DESC, sort ASC, id ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<int> insertCategory(Category c) async =>
      (await _db).insert('categories', c.toMap());

  Future<void> updateCategory(Category c) async => (await _db)
      .update('categories', c.toMap(), where: 'id = ?', whereArgs: [c.id]);

  Future<void> deleteCategory(int id) async =>
      (await _db).delete('categories', where: 'id = ?', whereArgs: [id]);

  // ---------- transactions ----------

  Future<int> insertTransaction(Transaction t) async =>
      (await _db).insert('transactions', t.toMap());

  Future<void> updateTransaction(Transaction t) async => (await _db).update(
        'transactions',
        t.toMap(),
        where: 'id = ?',
        whereArgs: [t.id],
      );

  Future<void> deleteTransaction(int id) async =>
      (await _db).delete('transactions', where: 'id = ?', whereArgs: [id]);

  /// 某月流水，按时间倒序
  Future<List<Transaction>> transactionsOfMonth(String monthKey) async {
    final rows = await (await _db).query(
      'transactions',
      where: 'substr(occurred_at, 1, 7) = ?',
      whereArgs: [monthKey],
      orderBy: 'occurred_at DESC, id DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  Future<int> monthExpenseCents(String monthKey) async {
    final r = await (await _db).rawQuery(
      "SELECT COALESCE(SUM(amount_cents), 0) AS s FROM transactions "
      "WHERE type = 'expense' AND substr(occurred_at, 1, 7) = ?",
      [monthKey],
    );
    return r.first['s'] as int;
  }

  Future<int> monthIncomeCents(String monthKey) async {
    final r = await (await _db).rawQuery(
      "SELECT COALESCE(SUM(amount_cents), 0) AS s FROM transactions "
      "WHERE type = 'income' AND substr(occurred_at, 1, 7) = ?",
      [monthKey],
    );
    return r.first['s'] as int;
  }

  /// 某月各分类支出合计：category_id -> cents
  Future<Map<int, int>> expenseByCategory(String monthKey) async {
    final rows = await (await _db).rawQuery(
      "SELECT category_id, SUM(amount_cents) AS s FROM transactions "
      "WHERE type = 'expense' AND substr(occurred_at, 1, 7) = ? GROUP BY category_id",
      [monthKey],
    );
    return {
      for (final r in rows) r['category_id'] as int: r['s'] as int,
    };
  }

  /// 全部流水（导出用），按时间升序
  Future<List<Transaction>> allTransactions() async {
    final rows = await (await _db).query(
      'transactions',
      orderBy: 'occurred_at ASC, id ASC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  /// 清空流水 / 配额 / 设置，保留分类表
  Future<void> clearAllData() async {
    final db = await _db;
    await db.delete('transactions');
    await db.delete('category_budgets');
    await db.delete('settings');
  }

  /// 删除所有非内置分类（测试重置用）
  Future<void> deleteCustomCategories() async {
    final db = await _db;
    await db.delete('categories', where: 'builtin = 0');
  }

  /// 某分类下流水数量（分类删除保护）
  Future<int> transactionCountByCategory(int categoryId) async {
    final r = await (await _db).rawQuery(
      'SELECT COUNT(*) AS c FROM transactions WHERE category_id = ?',
      [categoryId],
    );
    return r.first['c'] as int;
  }

  /// 全部设置键值对（备份用）
  Future<Map<String, String>> allSettings() async {
    final rows = await (await _db).query('settings');
    return {
      for (final r in rows) r['key'] as String: r['value'] as String,
    };
  }

  /// 全部分类配额（备份用）
  Future<List<CategoryBudget>> allCategoryBudgets() async {
    final rows = await (await _db).query('category_budgets');
    return rows.map(CategoryBudget.fromMap).toList();
  }

  /// 全量替换（恢复用）：在事务中清空并写入备份数据
  Future<void> replaceAllData({
    required List<Category> categories,
    required List<Transaction> transactions,
    required Map<String, String> settings,
    required List<CategoryBudget> categoryBudgets,
    List<RecurringBill> recurringBills = const [],
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('category_budgets');
      await txn.delete('settings');
      await txn.delete('categories');
      await txn.delete('recurring_bills');
      for (final c in categories) {
        await txn.insert(
          'categories',
          c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final t in transactions) {
        await txn.insert(
          'transactions',
          t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final e in settings.entries) {
        await txn.insert(
          'settings',
          {'key': e.key, 'value': e.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final b in categoryBudgets) {
        await txn.insert(
          'category_budgets',
          b.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final r in recurringBills) {
        await txn.insert(
          'recurring_bills',
          r.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// 某年每月支出合计：'YYYY-MM' -> cents（年度视图）
  Future<Map<String, int>> expenseByMonthOfYear(int year) async {
    final rows = await (await _db).rawQuery(
      "SELECT substr(occurred_at, 1, 7) AS m, SUM(amount_cents) AS s "
      "FROM transactions WHERE type = 'expense' AND substr(occurred_at, 1, 4) = ? "
      "GROUP BY m",
      [year.toString()],
    );
    return {
      for (final r in rows) r['m'] as String: r['s'] as int,
    };
  }

  /// 某年每天支出合计：'YYYY-MM-DD' -> cents（日历热力图）
  Future<Map<String, int>> expenseByDayOfYear(int year) async {
    final rows = await (await _db).rawQuery(
      "SELECT substr(occurred_at, 1, 10) AS d, SUM(amount_cents) AS s "
      "FROM transactions WHERE type = 'expense' AND substr(occurred_at, 1, 4) = ? "
      "GROUP BY d",
      [year.toString()],
    );
    return {
      for (final r in rows) r['d'] as String: r['s'] as int,
    };
  }

  // ---------- recurring bills ----------

  Future<List<RecurringBill>> recurringBills() async {
    final rows = await (await _db).query(
      'recurring_bills',
      orderBy: 'next_due_date ASC, id ASC',
    );
    return rows.map(RecurringBill.fromMap).toList();
  }

  /// 到期日 <= [date] 的账单（date-only 比较，字符串即可）
  Future<List<RecurringBill>> recurringBillsDueOn(DateTime date) async {
    final d = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final rows = await (await _db).query(
      'recurring_bills',
      where: 'next_due_date <= ?',
      whereArgs: [d],
      orderBy: 'next_due_date ASC, id ASC',
    );
    return rows.map(RecurringBill.fromMap).toList();
  }

  Future<int> insertRecurringBill(RecurringBill b) async =>
      (await _db).insert('recurring_bills', b.toMap());

  Future<void> updateRecurringBill(RecurringBill b) async => (await _db)
      .update('recurring_bills', b.toMap(), where: 'id = ?', whereArgs: [b.id]);

  Future<void> deleteRecurringBill(int id) async =>
      (await _db).delete('recurring_bills', where: 'id = ?', whereArgs: [id]);

  /// 清空全部周期账单（测试重置用）
  Future<void> clearRecurringBills() async {
    await (await _db).delete('recurring_bills');
  }

  /// 全部周期账单（备份用）
  Future<List<RecurringBill>> allRecurringBills() async {
    final rows = await (await _db).query(
      'recurring_bills',
      orderBy: 'next_due_date ASC, id ASC',
    );
    return rows.map(RecurringBill.fromMap).toList();
  }

  // ---------- settings ----------

  Future<String?> getSetting(String key) async {
    final rows = await (await _db)
        .query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async => (await _db).insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  // ---------- category budgets ----------

  Future<List<CategoryBudget>> budgetsOfMonth(String month) async {
    final rows = await (await _db).query(
      'category_budgets',
      where: 'month = ?',
      whereArgs: [month],
    );
    return rows.map(CategoryBudget.fromMap).toList();
  }

  /// 设置或覆盖某分类某月配额；limitCents <= 0 表示删除配额
  Future<void> setCategoryBudget({
    required int categoryId,
    required String month,
    required int limitCents,
  }) async {
    final db = await _db;
    if (limitCents <= 0) {
      await db.delete(
        'category_budgets',
        where: 'category_id = ? AND month = ?',
        whereArgs: [categoryId, month],
      );
      return;
    }
    await db.insert(
      'category_budgets',
      {
        'category_id': categoryId,
        'month': month,
        'limit_cents': limitCents,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}