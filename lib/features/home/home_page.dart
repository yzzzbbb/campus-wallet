import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/logic/finance_math.dart';
import '../../core/models/category.dart';
import '../../core/models/recurring_bill.dart';
import '../../core/models/transaction.dart';
import '../../core/theme/app_theme.dart';
import '../../state/budget_provider.dart';
import '../../state/category_provider.dart';
import '../../state/recurring_bills_provider.dart';
import '../../state/transaction_provider.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/category_icon.dart';

/// 首页：生活费倒计时卡片 + 本月概览 + 今日流水
class HomePage extends StatelessWidget {
  const HomePage({super.key, this.onAddTransaction, this.onOpenBudget});

  final VoidCallback? onAddTransaction;
  final VoidCallback? onOpenBudget;

  @override
  Widget build(BuildContext context) {
    final budget = context.watch<BudgetProvider>();
    final tx = context.watch<TransactionProvider>();
    final monthKey = FinanceMath.monthKey(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
          children: [
            _buildGreeting(context),
            const SizedBox(height: 16),
            if (!budget.setting.isConfigured)
              _UnconfiguredCard(onOpenBudget: onOpenBudget)
            else
              _CountdownCard(
                budget: budget,
                tx: tx,
                monthKey: monthKey,
                onOpenBudget: onOpenBudget,
              ),
            const SizedBox(height: 16),
            _MonthOverview(tx: tx, budget: budget, monthKey: monthKey),
            const SizedBox(height: 16),
            _DueBillsCard(tx: tx),
            const SizedBox(height: 16),
            _TodayTransactions(tx: tx, monthKey: monthKey),
          ],
        ),
      ),
      floatingActionButton: onAddTransaction == null
          ? null
          : FloatingActionButton(
              onPressed: onAddTransaction,
              tooltip: '记一笔',
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '生活费账本',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${now.year}年${now.month}月${now.day}日',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// 倒计时大卡片（R3/R4/R5/R8）
class _CountdownCard extends StatelessWidget {
  const _CountdownCard({
    required this.budget,
    required this.tx,
    required this.monthKey,
    this.onOpenBudget,
  });

  final BudgetProvider budget;
  final TransactionProvider tx;
  final String monthKey;
  final VoidCallback? onOpenBudget;

  @override
  Widget build(BuildContext context) {
    final days = budget.daysToNextPay;
    final effectiveBudget = budget.effectiveMonthlyBudgetCents;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16BD8C), Color(0xFF0B9E73)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_bottom, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(
                '生活费倒计时',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            days == 0 ? '今天发生活费！' : '还有 $days 天',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<int>(
            future: tx.monthExpenseCents(monthKey),
            builder: (context, snap) {
              final spent = snap.data ?? 0;
              final remaining = FinanceMath.remainingCents(
                monthlyBudgetCents: effectiveBudget,
                monthExpenseCents: spent,
              );
              final dailyCents =
                  FinanceMath.dailyAvailable(
                    remainingCents: remaining,
                    daysToNextPay: days,
                  ).round();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '剩余可用',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  remaining >= 0
                      ? AmountText(
                          cents: remaining,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : Text(
                          '已超支 ${AmountText.formatCents(-remaining)}',
                          style: const TextStyle(
                            color: Color(0xFFFFF3E0),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  const SizedBox(height: 4),
                  Text(
                    '日均可用 ${AmountText.formatCents(dailyCents)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
                onPressed: () => _receiveAllowance(context),
                icon: const Icon(Icons.payments, size: 18),
                label: const Text('收到生活费'),
              ),
              const Spacer(),
              TextButton(
                onPressed: onOpenBudget,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('预算规划'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// R8：记一笔生活费收入 + 重置倒计时
  Future<void> _receiveAllowance(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final cats =
        await context.read<CategoryProvider>().categoriesOf(Category.typeIncome);
    Category? target;
    for (final c in cats) {
      if (c.name == '生活费') {
        target = c;
        if (c.builtin) break;
      }
    }
    if (target == null || target.id == null) {
      messenger.showSnackBar(const SnackBar(content: Text('未找到生活费分类')));
      return;
    }
    final now = DateTime.now();
    await tx.add(
      Transaction(
        type: Transaction.typeIncome,
        amountCents: budget.setting.allowanceAmountCents,
        categoryId: target.id!,
        note: '生活费',
        occurredAt: now,
        createdAt: now,
      ),
    );
    await budget.saveSetting(budget.setting.copyWith(lastPayDate: now));
    messenger.showSnackBar(const SnackBar(content: Text('已记入生活费，倒计时已重置')));
  }
}

class _UnconfiguredCard extends StatelessWidget {
  const _UnconfiguredCard({this.onOpenBudget});

  final VoidCallback? onOpenBudget;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '开始规划你的生活费',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '设置生活费金额与发放周期，即可获得倒计时与预算提醒。',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onOpenBudget, child: const Text('去设置')),
          ],
        ),
      ),
    );
  }
}

/// 本月概览：支出/收入 + 预算进度
class _MonthOverview extends StatelessWidget {
  const _MonthOverview({
    required this.tx,
    required this.budget,
    required this.monthKey,
  });

  final TransactionProvider tx;
  final BudgetProvider budget;
  final String monthKey;

  @override
  Widget build(BuildContext context) {
    final effective = budget.effectiveMonthlyBudgetCents;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<(int, int)>(
          future: Future.wait<int>([
            tx.monthExpenseCents(monthKey),
            tx.monthIncomeCents(monthKey),
          ]).then((r) => (r[0], r[1])),
          builder: (context, snap) {
            final spent = snap.data?.$1 ?? 0;
            final income = snap.data?.$2 ?? 0;
            final p = effective <= 0 ? 0.0 : spent / effective;
            final v = p < 0 ? 0.0 : (p > 1 ? 1.0 : p);
            final color = p >= 1.0
                ? AppColors.over
                : (p >= 0.8 ? AppColors.warn : AppColors.primary);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('本月概览', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        label: '本月支出',
                        text: AmountText.formatCents(spent),
                        color: AppColors.expense,
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        label: '本月收入',
                        text: AmountText.formatCents(income),
                        color: AppColors.income,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '预算 ${AmountText.formatCents(effective)} · 已用 ${AmountText.formatCents(spent)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.text, required this.color});

  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          text,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

/// 今日流水
class _TodayTransactions extends StatelessWidget {
  const _TodayTransactions({required this.tx, required this.monthKey});

  final TransactionProvider tx;
  final String monthKey;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<(List<Transaction>, List<Category>)>(
          future: Future.wait([
            tx.transactionsOfMonth(monthKey),
            context.read<CategoryProvider>().categories(),
          ]).then(
            (r) => (r[0] as List<Transaction>, r[1] as List<Category>),
          ),
          builder: (context, snap) {
            final txs = snap.data?.$1 ?? const <Transaction>[];
            final cats = snap.data?.$2 ?? const <Category>[];
            final byId = {for (final c in cats) c.id: c};
            final now = DateTime.now();
            final today = txs.where((t) =>
                t.occurredAt.year == now.year &&
                t.occurredAt.month == now.month &&
                t.occurredAt.day == now.day).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('今日流水', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (today.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '今天还没有记账',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                else
                  ...today.map((t) {
                    final c = byId[t.categoryId];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          if (c != null)
                            CategoryIcon(icon: c.icon, color: c.color, size: 20),
                          if (c != null) const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              c?.name ?? '未知分类',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          AmountText(
                            cents: t.amountCents,
                            signed: t.isExpense,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: t.isExpense
                                  ? AppColors.expense
                                  : AppColors.income,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 周期账单到期提醒 + 一键入账
class _DueBillsCard extends StatelessWidget {
  const _DueBillsCard({required this.tx});

  final TransactionProvider tx;

  @override
  Widget build(BuildContext context) {
    final billsProvider = context.watch<RecurringBillsProvider>();
    return FutureBuilder<List<RecurringBill>>(
      future: billsProvider.dueBills(),
      builder: (context, snap) {
        final due = snap.data ?? const <RecurringBill>[];
        if (due.isEmpty) return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active_outlined,
                        size: 18, color: AppColors.warn),
                    SizedBox(width: 6),
                    Text('周期账单到期',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ...due.map(
                  (b) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${b.name} · ${AmountText.formatCents(b.amountCents)}',
                          ),
                        ),
                        Text(
                          '${b.nextDueDate.month}月${b.nextDueDate.day}日',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _settle(context, due),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text('一键入账（${due.length} 笔）'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _settle(BuildContext context, List<RecurringBill> due) async {
    final messenger = ScaffoldMessenger.of(context);
    final billsProvider = context.read<RecurringBillsProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认入账？'),
        content: Text(
          '将记录 ${due.length} 笔支出并顺延下次到期日：\n'
          '${due.map((b) => '· ${b.name} ${AmountText.formatCents(b.amountCents)}').join('\n')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('入账'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final now = DateTime.now();
    for (final b in due) {
      await tx.add(Transaction(
        type: Transaction.typeExpense,
        amountCents: b.amountCents,
        categoryId: b.categoryId,
        note: b.note.isEmpty ? b.name : '${b.name}：${b.note}',
        occurredAt: now,
        createdAt: now,
      ));
      await billsProvider.advance(b, now);
    }
    messenger.showSnackBar(
      SnackBar(content: Text('已入账 ${due.length} 笔周期账单')),
    );
  }
}