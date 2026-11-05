import 'package:flutter/foundation.dart';

import '../core/data/dao.dart';
import '../core/logic/finance_math.dart';
import '../core/models/transaction.dart';

/// 流水状态（契约：禁止改公开方法签名）
class TransactionProvider extends ChangeNotifier {
  final Map<String, List<Transaction>> _cache = {};

  Future<List<Transaction>> transactionsOfMonth(String monthKey) async {
    final cached = _cache[monthKey];
    if (cached != null) return cached;
    final list = await Dao.instance.transactionsOfMonth(monthKey);
    _cache[monthKey] = list;
    return list;
  }

  Future<void> add(Transaction t) async {
    await Dao.instance.insertTransaction(t);
    _cache.remove(FinanceMath.monthKey(t.occurredAt));
    notifyListeners();
  }

  Future<void> update(Transaction t) async {
    await Dao.instance.updateTransaction(t);
    _cache.clear();
    notifyListeners();
  }

  Future<void> delete(int id) async {
    await Dao.instance.deleteTransaction(id);
    _cache.clear();
    notifyListeners();
  }

  Future<int> monthExpenseCents(String monthKey) =>
      Dao.instance.monthExpenseCents(monthKey);

  Future<int> monthIncomeCents(String monthKey) =>
      Dao.instance.monthIncomeCents(monthKey);

  Future<Map<int, int>> expenseByCategory(String monthKey) =>
      Dao.instance.expenseByCategory(monthKey);

  Future<Map<String, int>> expenseByMonthOfYear(int year) =>
      Dao.instance.expenseByMonthOfYear(year);

  Future<Map<String, int>> expenseByDayOfYear(int year) =>
      Dao.instance.expenseByDayOfYear(year);
}