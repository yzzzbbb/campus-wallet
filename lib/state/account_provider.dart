import 'package:flutter/foundation.dart';

import '../core/data/dao.dart';
import '../core/models/account.dart';

/// 账户状态（契约：禁止改公开方法签名）
class AccountProvider extends ChangeNotifier {
  List<Account>? _cache;

  Future<List<Account>> accounts() async {
    final cached = _cache;
    if (cached != null) return cached;
    final list = await Dao.instance.accounts();
    _cache = list;
    return list;
  }

  Future<Account> add(String name) async {
    final accounts = await this.accounts();
    final id = await Dao.instance.insertAccount(Account(
      name: name,
      sort: accounts.length + 1,
    ));
    _cache = null;
    notifyListeners();
    return Account(id: id, name: name);
  }

  Future<void> rename(Account a, String name) async {
    await Dao.instance.updateAccount(a.copyWith(name: name));
    _cache = null;
    notifyListeners();
  }

  Future<void> delete(Account a) async {
    await Dao.instance.deleteAccount(a.id!);
    _cache = null;
    notifyListeners();
  }

  Future<int> transactionCount(Account a) =>
      Dao.instance.transactionCountByAccount(a.id!);
}