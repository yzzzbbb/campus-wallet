import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/logic/finance_math.dart';
import '../../core/models/budget_setting.dart';
import '../../core/models/category.dart';
import '../../core/models/category_budget.dart';
import '../../core/theme/app_theme.dart';
import '../../state/budget_provider.dart';
import '../../state/category_provider.dart';
import '../../state/transaction_provider.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/category_icon.dart';
import 'progress_tier.dart';

/// 预算规划页：生活费设置 + 月度预算总额 + 分类配额
class BudgetPage extends StatelessWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('预算规划')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _AllowanceSection(),
          SizedBox(height: 16),
          _MonthlyBudgetSection(),
          SizedBox(height: 16),
          _QuotaSection(),
        ],
      ),
    );
  }
}

/// 生活费设置区
class _AllowanceSection extends StatefulWidget {
  const _AllowanceSection();

  @override
  State<_AllowanceSection> createState() => _AllowanceSectionState();
}

class _AllowanceSectionState extends State<_AllowanceSection> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _everyNCtrl;
  late String _periodType;
  late int _payDay;
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    final s = context.read<BudgetProvider>().setting;
    _amountCtrl = TextEditingController(
      text: s.allowanceAmountCents > 0
          ? (s.allowanceAmountCents ~/ 100).toString()
          : '',
    );
    _everyNCtrl = TextEditingController(text: s.everyNDays.toString());
    _periodType = s.periodType;
    _payDay = s.payDay;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _everyNCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final yuan = int.tryParse(_amountCtrl.text.trim());
    if (yuan == null || yuan <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('请输入有效的生活费金额')));
      return;
    }
    final everyN = int.tryParse(_everyNCtrl.text.trim());
    if (_periodType == BudgetSetting.periodEveryNDays &&
        (everyN == null || everyN <= 0)) {
      messenger.showSnackBar(const SnackBar(content: Text('请输入有效的周期天数')));
      return;
    }
    final bp = context.read<BudgetProvider>();
    await bp.saveSetting(bp.setting.copyWith(
      allowanceAmountCents: yuan * 100,
      periodType: _periodType,
      payDay: _payDay,
      everyNDays: everyN ?? 30,
    ));
    messenger.showSnackBar(const SnackBar(content: Text('生活费设置已保存')));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('生活费设置',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '每次金额（元）',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: BudgetSetting.periodMonthly,
                  label: Text('每月固定日'),
                ),
                ButtonSegment(
                  value: BudgetSetting.periodEveryNDays,
                  label: Text('每 N 天'),
                ),
              ],
              selected: {_periodType},
              onSelectionChanged: (s) =>
                  setState(() => _periodType = s.first),
            ),
            const SizedBox(height: 12),
            if (_periodType == BudgetSetting.periodMonthly)
              DropdownButtonFormField<int>(
                initialValue: _payDay,
                decoration: const InputDecoration(
                  labelText: '每月发钱日',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (var d = 1; d <= 31; d++)
                    DropdownMenuItem(value: d, child: Text('$d 日')),
                ],
                onChanged: (v) => setState(() => _payDay = v ?? 1),
              )
            else
              TextField(
                controller: _everyNCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '周期天数',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('保存设置'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 月度预算总额区（R7）
class _MonthlyBudgetSection extends StatelessWidget {
  const _MonthlyBudgetSection();

  Future<void> _edit(BuildContext context) async {
    final bp = context.read<BudgetProvider>();
    final ctrl = TextEditingController(
      text: bp.effectiveMonthlyBudgetCents > 0
          ? (bp.effectiveMonthlyBudgetCents ~/ 100).toString()
          : '',
    );
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置月度预算总额（元）'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(prefixText: '¥ '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final yuan = int.tryParse(ctrl.text.trim());
      if (yuan == null || yuan <= 0) {
        messenger.showSnackBar(const SnackBar(content: Text('请输入有效金额')));
        return;
      }
      await bp.saveSetting(bp.setting.copyWith(monthlyBudgetCents: yuan * 100));
      messenger.showSnackBar(const SnackBar(content: Text('月度预算已更新')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BudgetProvider>();
    final overridden = bp.setting.monthlyBudgetCents != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('月度预算总额',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '当前：${AmountText.formatCents(bp.effectiveMonthlyBudgetCents)}'
              '${overridden ? '（手动设置）' : '（跟随生活费）'}',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => _edit(context),
                  child: const Text('修改'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    await bp.saveSetting(
                      bp.setting.copyWith(clearMonthlyBudget: true),
                    );
                  },
                  child: const Text('恢复默认'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 分类配额区（R6）
class _QuotaSection extends StatelessWidget {
  const _QuotaSection();

  Future<void> _editQuota(
    BuildContext context,
    Category c,
    int currentLimitCents,
  ) async {
    final bp = context.read<BudgetProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController(
      text: currentLimitCents > 0
          ? (currentLimitCents ~/ 100).toString()
          : '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('设置「${c.name}」月度配额（元）'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            prefixText: '¥ ',
            hintText: '留空或 0 = 删除配额',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final text = ctrl.text.trim();
    final yuan = text.isEmpty ? 0 : int.tryParse(text);
    if (yuan == null) {
      messenger.showSnackBar(const SnackBar(content: Text('请输入有效金额')));
      return;
    }
    await bp.setCategoryBudget(
      categoryId: c.id!,
      month: FinanceMath.monthKey(DateTime.now()),
      limitCents: yuan <= 0 ? 0 : yuan * 100,
    );
    messenger.showSnackBar(const SnackBar(content: Text('配额已更新')));
  }

  Color _tierColor(ProgressTier tier) {
    switch (tier) {
      case ProgressTier.warn:
        return AppColors.warn;
      case ProgressTier.over:
        return AppColors.over;
      case ProgressTier.normal:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CategoryProvider>();
    final tx = context.watch<TransactionProvider>();
    final bp = context.watch<BudgetProvider>();
    final monthKey = FinanceMath.monthKey(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<(
          List<Category>,
          Map<int, int>,
          List<CategoryBudget>
        )>(
          future: Future.wait([
            cp.categories(),
            tx.expenseByCategory(monthKey),
            bp.budgetsOfMonth(monthKey),
          ]).then(
            (r) => (
              r[0] as List<Category>,
              r[1] as Map<int, int>,
              (r[2] as List).cast<CategoryBudget>(),
            ),
          ),
          builder: (context, snap) {
            final cats = snap.data?.$1 ?? const <Category>[];
            final spent = snap.data?.$2 ?? const <int, int>{};
            final quotas = snap.data?.$3 ?? const <CategoryBudget>[];
            final expenseCats = cats.where((c) => c.isExpense).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('分类配额（本月）',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (expenseCats.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('暂无支出分类'),
                  )
                else
                  ...expenseCats.map((c) {
                    CategoryBudget? quota;
                    for (final q in quotas) {
                      if (q.categoryId == c.id) {
                        quota = q;
                        break;
                      }
                    }
                    final limit = quota?.limitCents ?? 0;
                    final s = spent[c.id] ?? 0;
                    final p = limit > 0 ? s / limit : 0.0;
                    final tier = limit > 0 ? progressTierFor(p) : null;
                    final v = p < 0 ? 0.0 : (p > 1 ? 1.0 : p);
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _editQuota(context, c, limit),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            CategoryIcon(icon: c.icon, color: c.color, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name),
                                  const SizedBox(height: 4),
                                  if (limit > 0) ...[
                                    LinearProgressIndicator(
                                      value: v,
                                      minHeight: 6,
                                      color: _tierColor(tier!),
                                      backgroundColor: _tierColor(tier)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '已花 ${AmountText.formatCents(s)} / 配额 ${AmountText.formatCents(limit)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ] else
                                    Text(
                                      '已花 ${AmountText.formatCents(s)} · 未设配额',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right,
                                size: 18, color: Colors.grey),
                          ],
                        ),
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