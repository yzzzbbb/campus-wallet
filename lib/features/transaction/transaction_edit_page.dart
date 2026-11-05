import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/account.dart';
import '../../core/models/category.dart';
import '../../core/models/transaction.dart';
import '../../state/account_provider.dart';
import '../../state/category_provider.dart';
import '../../state/transaction_provider.dart';
import '../../widgets/category_icon.dart';

/// 记账页（新增/编辑流水）
class TransactionEditPage extends StatefulWidget {
  const TransactionEditPage({
    super.key,
    this.existing,
    this.initialType = Transaction.typeExpense,
  });

  final Transaction? existing;
  final String initialType;

  @override
  State<TransactionEditPage> createState() => _TransactionEditPageState();
}

class _TransactionEditPageState extends State<TransactionEditPage> {
  late String _type;
  String _amountText = '';
  int? _categoryId;
  int? _accountId;
  late DateTime _date;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? widget.initialType;
    if (e != null) {
      _categoryId = e.categoryId;
      _accountId = e.accountId;
      _date = e.occurredAt;
      _amountText = _centsToInput(e.amountCents);
      _noteController = TextEditingController(text: e.note);
    } else {
      _date = DateTime.now();
      _noteController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  static String _centsToInput(int cents) {
    final yuan = cents ~/ 100;
    final fen = cents % 100;
    if (fen == 0) return '$yuan';
    return '$yuan.${fen.toString().padLeft(2, '0')}';
  }

  /// 解析金额为分；禁止 double 运算
  int? _parseCents() {
    final s = _amountText.trim();
    if (s.isEmpty) return null;
    if (!RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(s)) return null;
    final parts = s.split('.');
    final yuan = int.parse(parts[0]);
    if (yuan > 9999999) return null;
    final fen = parts.length > 1 && parts[1].isNotEmpty
        ? int.parse(parts[1].padRight(2, '0'))
        : 0;
    return yuan * 100 + fen;
  }

  void _onKey(String key) {
    setState(() {
      if (key == 'back') {
        if (_amountText.isNotEmpty) {
          _amountText = _amountText.substring(0, _amountText.length - 1);
        }
      } else if (key == '.') {
        if (!_amountText.contains('.')) {
          _amountText = _amountText.isEmpty ? '0.' : '$_amountText.';
        }
      } else {
        final dot = _amountText.indexOf('.');
        if (dot >= 0 && _amountText.length - dot - 1 >= 2) return;
        if (_amountText == '0') {
          _amountText = key;
        } else {
          _amountText = '$_amountText$key';
        }
      }
    });
  }

  Future<void> _save() async {
    final cents = _parseCents();
    final messenger = ScaffoldMessenger.of(context);
    if (cents == null || cents <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('请输入有效金额')));
      return;
    }
    if (_categoryId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('请选择分类')));
      return;
    }
    final tx = context.read<TransactionProvider>();
    final e = widget.existing;
    final note = _noteController.text.trim();
    if (e == null) {
      await tx.add(Transaction(
        type: _type,
        amountCents: cents,
        categoryId: _categoryId!,
        accountId: _accountId,
        note: note,
        occurredAt: _date,
        createdAt: DateTime.now(),
      ));
    } else {
      await tx.update(e.copyWith(
        type: _type,
        amountCents: cents,
        categoryId: _categoryId,
        accountId: _accountId,
        note: note,
        occurredAt: _date,
      ));
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  String get _displayAmount => _amountText.isEmpty ? '0.00' : _amountText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? '记一笔' : '编辑流水'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Center(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: Transaction.typeExpense,
                    label: Text('支出'),
                  ),
                  ButtonSegment(
                    value: Transaction.typeIncome,
                    label: Text('收入'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _categoryId = null;
                }),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '¥ $_displayAmount',
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            _NumberPad(onKey: _onKey),
            const SizedBox(height: 20),
            Text(
              '分类',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _CategoryGrid(
              type: _type,
              selectedId: _categoryId,
              onSelect: (id) => setState(() => _categoryId = id),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('日期'),
              trailing: Text(
                '${_date.year}年${_date.month}月${_date.day}日',
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() => _date = DateTime(
                      picked.year, picked.month, picked.day,
                      _date.hour, _date.minute));
                }
              },
            ),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注',
                hintText: '可选',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _AccountSelector(
              selectedId: _accountId,
              onSelect: (id) => setState(() => _accountId = id),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('保存', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSelector extends StatelessWidget {
  const _AccountSelector({required this.selectedId, required this.onSelect});

  final int? selectedId;
  final void Function(int? id) onSelect;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Account>>(
      future: context.read<AccountProvider>().accounts(),
      builder: (context, snap) {
        final accounts = snap.data ?? const <Account>[];
        return DropdownButtonFormField<int?>(
          initialValue: selectedId,
          decoration: const InputDecoration(
            labelText: '账户',
            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('不指定账户'),
            ),
            for (final a in accounts)
              DropdownMenuItem<int?>(
                value: a.id,
                child: Text(a.name),
              ),
          ],
          onChanged: onSelect,
        );
      },
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({required this.onKey});

  final void Function(String key) onKey;

  static const _keys = [
    '1', '2', '3',
    '4', '5', '6',
    '7', '8', '9',
    '.', '0', 'back',
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      children: [
        for (final k in _keys)
          TextButton(
            onPressed: () => onKey(k),
            child: k == 'back'
                ? const Icon(Icons.backspace_outlined)
                : Text(k, style: const TextStyle(fontSize: 22)),
          ),
      ],
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.type,
    required this.selectedId,
    required this.onSelect,
  });

  final String type;
  final int? selectedId;
  final void Function(int id) onSelect;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: context.read<CategoryProvider>().categoriesOf(type),
      builder: (context, snap) {
        final cats = snap.data ?? const <Category>[];
        if (cats.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Text('暂无分类'),
          );
        }
        return GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final c in cats)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelect(c.id!),
                child: Container(
                  decoration: BoxDecoration(
                    color: selectedId == c.id
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CategoryIcon(icon: c.icon, color: c.color, size: 26),
                      const SizedBox(height: 4),
                      Text(
                        c.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selectedId == c.id
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}