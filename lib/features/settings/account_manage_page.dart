import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/account.dart';
import '../../state/account_provider.dart';
import '../../widgets/category_icon.dart';

/// 账户管理页：新增 / 改名 / 删除（内置账户与有流水的账户受保护）
class AccountManagePage extends StatelessWidget {
  const AccountManagePage({super.key});

  Future<void> _add(BuildContext context) async {
    final provider = context.read<AccountProvider>();
    final name = await _promptName(context, title: '新增账户');
    if (name == null || name.isEmpty) return;
    await provider.add(name);
  }

  Future<void> _rename(BuildContext context, Account a) async {
    final provider = context.read<AccountProvider>();
    final name = await _promptName(context, title: '重命名账户', initial: a.name);
    if (name == null || name.isEmpty || name == a.name) return;
    await provider.rename(a, name);
  }

  Future<void> _delete(BuildContext context, Account a) async {
    final provider = context.read<AccountProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final count = await provider.transactionCount(a);
    if (!context.mounted) return;
    if (a.builtin) {
      messenger.showSnackBar(
        const SnackBar(content: Text('内置账户不可删除')),
      );
      return;
    }
    if (count > 0) {
      messenger.showSnackBar(
        SnackBar(content: Text('该账户下有 $count 笔流水，无法删除')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账户？'),
        content: Text('将删除「${a.name}」，且无法撤销。'),
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
      await provider.delete(a);
    }
  }

  Future<String?> _promptName(
    BuildContext context, {
    required String title,
    String initial = '',
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 10,
          decoration: const InputDecoration(hintText: '例如：微信、支付宝、校园卡'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账户管理')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('新增账户'),
      ),
      body: FutureBuilder<List<Account>>(
        future: context.read<AccountProvider>().accounts(),
        builder: (context, snap) {
          final accounts = snap.data ?? const <Account>[];
          if (accounts.isEmpty) {
            return const Center(child: Text('暂无账户'));
          }
          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, i) {
              final a = accounts[i];
              return ListTile(
                leading: CategoryIcon(icon: a.icon, color: a.color),
                title: Text(a.name),
                subtitle: a.builtin ? const Text('内置') : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _rename(context, a),
                    ),
                    if (!a.builtin)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _delete(context, a),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}