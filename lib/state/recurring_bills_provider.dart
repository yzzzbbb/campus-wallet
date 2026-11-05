import 'package:flutter/foundation.dart';

import '../core/data/dao.dart';
import '../core/logic/recurring_math.dart';
import '../core/models/recurring_bill.dart';

/// 周期账单状态（契约：禁止改公开方法签名）
class RecurringBillsProvider extends ChangeNotifier {
  List<RecurringBill>? _cache;

  Future<List<RecurringBill>> bills() async {
    if (_cache != null) return _cache!;
    _cache = await Dao.instance.recurringBills();
    return _cache!;
  }

  /// 已到期（next_due_date <= 今天）的账单
  Future<List<RecurringBill>> dueBills() async =>
      Dao.instance.recurringBillsDueOn(DateTime.now());

  Future<void> add(RecurringBill b) async {
    await Dao.instance.insertRecurringBill(b);
    _cache = null;
    notifyListeners();
  }

  Future<void> update(RecurringBill b) async {
    await Dao.instance.updateRecurringBill(b);
    _cache = null;
    notifyListeners();
  }

  Future<void> delete(int id) async {
    await Dao.instance.deleteRecurringBill(id);
    _cache = null;
    notifyListeners();
  }

  /// 入账后顺延下次到期日
  Future<void> advance(RecurringBill b, DateTime paidOn) async {
    final next = RecurringMath.nextDueDate(
      periodType: b.periodType,
      periodValue: b.periodValue,
      currentDue: b.nextDueDate,
      from: paidOn,
    );
    await Dao.instance.updateRecurringBill(b.copyWith(nextDueDate: next));
    _cache = null;
    notifyListeners();
  }
}