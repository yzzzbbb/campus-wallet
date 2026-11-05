import 'dart:convert';

import '../../core/data/dao.dart';
import '../../core/models/category.dart';
import '../../core/models/category_budget.dart';
import '../../core/models/recurring_bill.dart';
import '../../core/models/transaction.dart';

/// 备份 / 恢复服务（纯本地 JSON，无网络）
class BackupService {
  BackupService._();

  static const appTag = 'campus_wallet';
  static const schemaVersion = 1;

  /// 生成完整备份 JSON 字符串（分类、流水、设置、配额、周期账单）
  static Future<String> buildBackupJson() async {
    final dao = Dao.instance;
    final data = <String, dynamic>{
      'app': appTag,
      'version': schemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'categories': (await dao.categories()).map((c) => c.toMap()).toList(),
      'transactions':
          (await dao.allTransactions()).map((t) => t.toMap()).toList(),
      'settings': await dao.allSettings(),
      'category_budgets':
          (await dao.allCategoryBudgets()).map((b) => b.toMap()).toList(),
      'recurring_bills':
          (await dao.allRecurringBills()).map((b) => b.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 校验并全量恢复；失败抛 [FormatException]，不破坏现有数据
  static Future<void> restoreFromJson(String jsonStr) async {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份格式错误：不是 JSON 对象');
    }
    if (decoded['app'] != appTag) {
      throw const FormatException('这不是「生活费账本」的备份文件');
    }
    if (decoded['version'] != schemaVersion) {
      throw const FormatException('备份版本不支持，请升级应用');
    }
    final categories =
        _parseList<Map<String, dynamic>>(decoded['categories'])
            .map(Category.fromMap)
            .toList();
    final transactions =
        _parseList<Map<String, dynamic>>(decoded['transactions'])
            .map(Transaction.fromMap)
            .toList();
    final budgets = _parseList<Map<String, dynamic>>(decoded['category_budgets'])
        .map(CategoryBudget.fromMap)
        .toList();
    // 旧版备份可能没有周期账单字段，视为空列表
    final recurringBills = decoded['recurring_bills'] is List
        ? (_parseList<Map<String, dynamic>>(decoded['recurring_bills'])
            .map(RecurringBill.fromMap)
            .toList())
        : const <RecurringBill>[];
    final settingsRaw = decoded['settings'];
    final settings = <String, String>{};
    if (settingsRaw is Map) {
      for (final e in settingsRaw.entries) {
        settings[e.key.toString()] = e.value.toString();
      }
    }
    if (categories.isEmpty) {
      throw const FormatException('备份内容无效：分类为空');
    }
    await Dao.instance.replaceAllData(
      categories: categories,
      transactions: transactions,
      settings: settings,
      categoryBudgets: budgets,
      recurringBills: recurringBills,
    );
  }

  static List<T> _parseList<T>(Object? v) {
    if (v is List) return v.cast<T>();
    throw const FormatException('备份格式错误：缺少数组字段');
  }
}