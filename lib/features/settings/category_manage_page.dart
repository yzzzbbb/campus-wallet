import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/data/dao.dart';
import '../../core/models/category.dart';
import '../../state/category_provider.dart';
import '../../widgets/category_icon.dart';

/// 分类管理页：新增 / 改名 / 换图标 / 换色 / 删除（内置与流水保护）/ 排序
class CategoryManagePage extends StatefulWidget {
  const CategoryManagePage({super.key});

  @override
  State<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends State<CategoryManagePage> {
  String _type = Category.typeExpense;

  static const _palette = <int>[
    0xFFFF7043, 0xFF42A5F5, 0xFF7E57C2, 0xFF26A69A, 0xFFEC407A, 0xFF8D6E63,
    0xFFEF5350, 0xFFAB47BC, 0xFF78909C, 0xFF66BB6A, 0xFF5C6BC0, 0xFFFFA726,
  ];

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CategoryProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新增分类',
            onPressed: () => _edit(context, null),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: Category.typeExpense,
                  label: Text('支出分类'),
                ),
                ButtonSegment(
                  value: Category.typeIncome,
                  label: Text('收入分类'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Category>>(
              future: cp.categoriesOf(_type),
              builder: (context, snap) {
                final cats = snap.data ?? const <Category>[];
                if (cats.isEmpty) {
                  return const Center(child: Text('暂无分类'));
                }
                return ListView.builder(
                  itemCount: cats.length,
                  itemBuilder: (context, i) {
                    final c = cats[i];
                    return ListTile(
                      leading: CategoryIcon(icon: c.icon, color: c.color),
                      title: Text(c.builtin ? '${c.name}（内置）' : c.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward, size: 18),
                            onPressed: i == 0
                                ? null
                                : () => _move(cp, cats, i, -1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward, size: 18),
                            onPressed: i == cats.length - 1
                                ? null
                                : () => _move(cp, cats, i, 1),
                          ),
                          if (!c.builtin)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => _confirmDelete(context, c),
                            ),
                        ],
                      ),
                      onTap: () => _edit(context, c),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _move(
    CategoryProvider cp,
    List<Category> cats,
    int i,
    int delta,
  ) async {
    final a = cats[i];
    final b = cats[i + delta];
    await cp.updateCategory(a.copyWith(sort: b.sort));
    await cp.updateCategory(b.copyWith(sort: a.sort));
  }

  Future<void> _confirmDelete(BuildContext context, Category c) async {
    final messenger = ScaffoldMessenger.of(context);
    final cp = context.read<CategoryProvider>();
    final count = await Dao.instance.transactionCountByCategory(c.id!);
    if (count > 0) {
      messenger.showSnackBar(const SnackBar(content: Text('该分类已有流水，无法删除')));
      return;
    }
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${c.name}」？'),
        content: const Text('删除后不可恢复。'),
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
      await cp.deleteCategory(c.id!);
      messenger.showSnackBar(const SnackBar(content: Text('已删除')));
    }
  }

  Future<void> _edit(BuildContext context, Category? c) async {
    final cp = context.read<CategoryProvider>();
    final result = await showDialog<CategoryDraft>(
      context: context,
      builder: (_) => _CategoryEditDialog(category: c, type: _type),
    );
    if (result == null || result.name.isEmpty) return;
    if (c == null) {
      await cp.addCategory(Category(
        name: result.name,
        type: result.type,
        icon: result.icon,
        color: result.color,
        sort: 99, // 新分类排最后
      ));
    } else {
      await cp.updateCategory(
        c.copyWith(name: result.name, icon: result.icon, color: result.color),
      );
    }
  }
}

class CategoryDraft {
  const CategoryDraft({
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });

  final String name;
  final String type;
  final String icon;
  final int color;
}

class _CategoryEditDialog extends StatefulWidget {
  const _CategoryEditDialog({this.category, required this.type});

  final Category? category;
  final String type;

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late final TextEditingController _nameCtrl;
  late String _icon;
  late int _color;

  String get _type => widget.category?.type ?? widget.type;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category?.name ?? '');
    _icon = widget.category?.icon ?? 'more_horiz';
    _color = widget.category?.color ?? 0xFF42A5F5;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? '新增分类' : '编辑分类'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: '名称'),
          ),
          const SizedBox(height: 16),
          const Text('图标'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in CategoryIcon.iconNames)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _icon = name),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _icon == name
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.15)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Icon(CategoryIcon.iconDataOf(name)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('颜色'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _CategoryManagePageState._palette)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: _color == c
                          ? Border.all(width: 3, color: Colors.black87)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            CategoryDraft(
              name: _nameCtrl.text.trim(),
              type: _type,
              icon: _icon,
              color: _color,
            ),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}