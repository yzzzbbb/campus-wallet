import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/logic/finance_math.dart';
import '../../core/models/account.dart';
import '../../core/models/category.dart';
import '../../core/models/transaction.dart';
import '../../core/theme/app_theme.dart';
import '../../state/account_provider.dart';
import '../../state/category_provider.dart';
import '../../state/transaction_provider.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/category_icon.dart';
import 'transaction_edit_page.dart';

/// 流水列表页：月份切换 + 按日分组
class TransactionListPage extends StatefulWidget {
  const TransactionListPage({super.key});

  @override
  State<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends State<TransactionListPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  void _shift(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
  }

  Future<void> _openEdit(Transaction t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TransactionEditPage(existing: t),
      ),
    );
  }

  Future<void> _confirmDelete(Transaction t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条流水？'),
        content: Text(
          '${t.isExpense ? '支出' : '收入'} ${AmountText.formatCents(t.amountCents)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<TransactionProvider>().delete(t.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = context.watch<TransactionProvider>();
    final monthKey = FinanceMath.monthKey(_month);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _shift(-1),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${_month.year}年${_month.month}月',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _shift(1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<(List<Transaction>, List<Category>, List<Account>)>(
                future: Future.wait([
                  tx.transactionsOfMonth(monthKey),
                  context.read<CategoryProvider>().categories(),
                  context.read<AccountProvider>().accounts(),
                ]).then(
                  (r) => (
                    r[0] as List<Transaction>,
                    r[1] as List<Category>,
                    r[2] as List<Account>,
                  ),
                ),
                builder: (context, snap) {
                  final txs = snap.data?.$1 ?? const <Transaction>[];
                  final cats = snap.data?.$2 ?? const <Category>[];
                  final accounts = snap.data?.$3 ?? const <Account>[];
                  final byId = {for (final c in cats) c.id: c};
                  final accountNameById = {
                    for (final a in accounts) a.id: a.name,
                  };
                  if (txs.isEmpty) {
                    return Center(
                      child: Text(
                        '本月暂无流水',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    );
                  }
                  final groups = <DateTime, List<Transaction>>{};
                  for (final t in txs) {
                    final d = DateTime(
                      t.occurredAt.year,
                      t.occurredAt.month,
                      t.occurredAt.day,
                    );
                    groups.putIfAbsent(d, () => []).add(t);
                  }
                  final days = groups.keys.toList()
                    ..sort((a, b) => b.compareTo(a));
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    children: [
                      for (final day in days) ...[
                        _DayHeader(day: day, items: groups[day]!),
                        for (final t in groups[day]!)
                          _TransactionTile(
                            t: t,
                            category: byId[t.categoryId],
                            accountName: t.accountId == null
                                ? null
                                : accountNameById[t.accountId],
                            onTap: () => _openEdit(t),
                            onLongPress: () => _confirmDelete(t),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.items});

  final DateTime day;
  final List<Transaction> items;

  @override
  Widget build(BuildContext context) {
    final week = _TransactionListPageState._weekdays[day.weekday - 1];
    var expense = 0;
    for (final t in items) {
      if (t.isExpense) expense += t.amountCents;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            '${day.month}月${day.day}日 $week',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const Spacer(),
          if (expense > 0)
            Text(
              '支出 ${AmountText.formatCents(expense)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.t,
    required this.category,
    required this.accountName,
    required this.onTap,
    required this.onLongPress,
  });

  final Transaction t;
  final Category? category;
  final String? accountName;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            if (category != null)
              CategoryIcon(icon: category!.icon, color: category!.color),
            if (category != null) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(category?.name ?? '未知分类', style: const TextStyle(fontSize: 15)),
                      if (accountName != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            accountName!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (t.note.isNotEmpty)
                    Text(
                      t.note,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),
            AmountText(
              cents: t.amountCents,
              signed: t.isExpense,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: t.isExpense ? AppColors.expense : AppColors.income,
              ),
            ),
          ],
        ),
      ),
    );
  }
}