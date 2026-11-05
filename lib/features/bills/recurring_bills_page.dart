import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/logic/recurring_math.dart';
import '../../core/models/category.dart';
import '../../core/models/recurring_bill.dart';
import '../../state/category_provider.dart';
import '../../state/recurring_bills_provider.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/category_icon.dart';

/// 周期账单管理页：订阅、话费、健身卡等固定周期支出
class RecurringBillsPage extends StatelessWidget {
  const RecurringBillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecurringBillsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('周期账单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新增周期账单',
            onPressed: () => _edit(context, null),
          ),
        ],
      ),
      body: FutureBuilder<List<RecurringBill>>(
        future: provider.bills(),
        builder: (context, snap) {
          final bills = snap.data ?? const <RecurringBill>[];
          if (bills.isEmpty) {
            return Center(
              child: Text(
                '还没有周期账单\n点右上角 + 添加订阅、话费等固定支出',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            );
          }
          final now = DateTime.now();
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: bills.length,
            itemBuilder: (context, i) {
              final b = bills[i];
              final due = DateTime(
                  b.nextDueDate.year, b.nextDueDate.month, b.nextDueDate.day);
              final today = DateTime(now.year, now.month, now.day);
              final leftDays = due.difference(today).inDays;
              final dueText = leftDays < 0
                  ? '已过期 ${-leftDays} 天'
                  : (leftDays == 0 ? '今天到期' : '还有 $leftDays 天');
              return FutureBuilder<List<Category>>(
                future: context.read<CategoryProvider>().categories(),
                builder: (context, catSnap) {
                  final cats = catSnap.data ?? const <Category>[];
                  Category? cat;
                  for (final c in cats) {
                    if (c.id == b.categoryId) {
                      cat = c;
                      break;
                    }
                  }
                  return ListTile(
                    leading: cat == null
                        ? const Icon(Icons.receipt_long)
                        : CategoryIcon(icon: cat.icon, color: cat.color),
                    title: Text(b.name),
                    subtitle: Text(
                      '${AmountText.formatCents(b.amountCents)} · '
                      '下次 ${b.nextDueDate.month}月${b.nextDueDate.day}日 · $dueText',
                      style: TextStyle(
                        fontSize: 12,
                        color: leftDays <= 0
                            ? Theme.of(context).colorScheme.error
                            : Colors.grey.shade600,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _confirmDelete(context, b),
                    ),
                    onTap: () => _edit(context, b),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, RecurringBill b) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<RecurringBillsProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${b.name}」？'),
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
    if (ok == true) {
      await provider.delete(b.id!);
      messenger.showSnackBar(const SnackBar(content: Text('已删除')));
    }
  }

  Future<void> _edit(BuildContext context, RecurringBill? b) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<RecurringBillsProvider>();
    final result = await showDialog<BillDraft>(
      context: context,
      builder: (_) => _BillEditDialog(bill: b),
    );
    if (result == null || result.name.isEmpty || result.amountCents <= 0) {
      return;
    }
    if (result.categoryId <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('请选择支出分类')));
      return;
    }
    if (b == null) {
      await provider.add(RecurringBill(
        name: result.name,
        amountCents: result.amountCents,
        categoryId: result.categoryId,
        periodType: result.periodType,
        periodValue: result.periodValue,
        nextDueDate: RecurringMath.nextDueDate(
          periodType: result.periodType,
          periodValue: result.periodValue,
          currentDue: result.firstDueDate,
          from: result.firstDueDate,
        ),
        note: result.note,
      ));
    } else {
      await provider.update(b.copyWith(
        name: result.name,
        amountCents: result.amountCents,
        categoryId: result.categoryId,
        periodType: result.periodType,
        periodValue: result.periodValue,
        note: result.note,
      ));
    }
  }
}

class BillDraft {
  const BillDraft({
    required this.name,
    required this.amountCents,
    required this.categoryId,
    required this.periodType,
    required this.periodValue,
    required this.firstDueDate,
    required this.note,
  });

  final String name;
  final int amountCents;
  final int categoryId;
  final String periodType;
  final int periodValue;
  final DateTime firstDueDate;
  final String note;
}

class _BillEditDialog extends StatefulWidget {
  const _BillEditDialog({this.bill});

  final RecurringBill? bill;

  @override
  State<_BillEditDialog> createState() => _BillEditDialogState();
}

class _BillEditDialogState extends State<_BillEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _periodCtrl;
  late String _periodType;
  int? _categoryId;
  late DateTime _firstDue;

  @override
  void initState() {
    super.initState();
    final b = widget.bill;
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _amountCtrl = TextEditingController(
      text: b != null && b.amountCents > 0 ? '${b.amountCents ~/ 100}' : '',
    );
    _noteCtrl = TextEditingController(text: b?.note ?? '');
    _periodCtrl = TextEditingController(text: '${b?.periodValue ?? 1}');
    _periodType = b?.periodType ?? RecurringBill.periodMonthly;
    _categoryId = b?.categoryId;
    _firstDue = b?.nextDueDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _periodCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.bill == null;
    return AlertDialog(
      title: Text(isNew ? '新增周期账单' : '编辑周期账单'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: '名称（如：视频会员）'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '金额（元）', prefixText: '¥ '),
          ),
          const SizedBox(height: 12),
          const Text('支出分类'),
          const SizedBox(height: 8),
          FutureBuilder<List<Category>>(
            future: context.read<CategoryProvider>().categoriesOf(Category.typeExpense),
            builder: (context, snap) {
              final cats = snap.data ?? const <Category>[];
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in cats)
                    ChoiceChip(
                      label: Text(c.name),
                      avatar: CategoryIcon(icon: c.icon, color: c.color, size: 16),
                      selected: _categoryId == c.id,
                      onSelected: (_) => setState(() => _categoryId = c.id),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: RecurringBill.periodMonthly,
                label: Text('每月固定日'),
              ),
              ButtonSegment(
                value: RecurringBill.periodEveryNDays,
                label: Text('每 N 天'),
              ),
            ],
            selected: {_periodType},
            onSelectionChanged: (s) => setState(() => _periodType = s.first),
          ),
          const SizedBox(height: 12),
          if (_periodType == RecurringBill.periodMonthly)
            DropdownButtonFormField<int>(
              initialValue: int.tryParse(_periodCtrl.text) ?? 1,
              decoration: const InputDecoration(labelText: '每月几号', border: OutlineInputBorder()),
              items: [
                for (var d = 1; d <= 31; d++)
                  DropdownMenuItem(value: d, child: Text('$d 号')),
              ],
              onChanged: (v) =>
                  setState(() => _periodCtrl.text = '${v ?? 1}'),
            )
          else
            TextField(
              controller: _periodCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '间隔天数', border: OutlineInputBorder()),
            ),
          if (isNew) ...[
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('首次到期日'),
              trailing: Text(
                '${_firstDue.year}年${_firstDue.month}月${_firstDue.day}日',
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _firstDue,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _firstDue = picked);
              },
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: '备注（可选）'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final yuan = int.tryParse(_amountCtrl.text.trim());
            final pv = int.tryParse(_periodCtrl.text.trim()) ?? 1;
            Navigator.pop(
              context,
              BillDraft(
                name: _nameCtrl.text.trim(),
                amountCents: yuan == null ? 0 : yuan * 100,
                categoryId: _categoryId ?? 0,
                periodType: _periodType,
                periodValue: pv,
                firstDueDate: _firstDue,
                note: _noteCtrl.text.trim(),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}