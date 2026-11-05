import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/data/dao.dart';
import '../../state/settings_provider.dart';
import '../../widgets/amount_text.dart';
import '../bills/recurring_bills_page.dart';
import 'backup_service.dart';
import 'category_manage_page.dart';

/// 设置页（MVP：深色模式 / 导出 CSV / 清空数据 / 关于）
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('分类管理'),
            subtitle: const Text('新增 / 改名 / 换图标与颜色 / 排序'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoryManagePage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('周期账单'),
            subtitle: const Text('订阅、话费、健身卡等固定支出提醒'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecurringBillsPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('深色模式'),
            subtitle: const Text('跟随系统 / 手动切换'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
                ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
                ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('导出数据 CSV'),
            subtitle: const Text('导出全部流水到应用文档目录'),
            onTap: () => _exportCsv(context),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('备份数据 (JSON)'),
            subtitle: const Text('完整备份到文件，换机恢复不丢数据'),
            onTap: () => _backup(context),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('恢复数据'),
            subtitle: const Text('从备份文件恢复（覆盖当前数据）'),
            onTap: () => _restore(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('清空所有数据'),
            subtitle: const Text('删除全部流水与设置（不可恢复）'),
            onTap: () => _clearAll(context),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('关于'),
            subtitle: Text(
              'campus-wallet v0.1\n'
              '面向大学生的生活费记账与规划 App\n'
              '无广告 · 无联网 · 数据全在本机',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final txs = await Dao.instance.allTransactions();
    if (txs.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('暂无数据可导出')));
      return;
    }
    final cats = await Dao.instance.categories();
    final nameById = {for (final c in cats) c.id: c.name};
    final buffer = StringBuffer('时间,类型,分类,金额(元),备注\n');
    for (final t in txs) {
      final time = DateFormat('yyyy-MM-dd HH:mm:ss').format(t.occurredAt);
      buffer.writeln(
        '$time,${t.isExpense ? '支出' : '收入'},${nameById[t.categoryId] ?? t.categoryId},'
        '${AmountText.formatCents(t.amountCents)},${t.note.replaceAll(',', '，')}',
      );
    }
    final dir = await getApplicationDocumentsDirectory();
    final name =
        'campus_wallet_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsString(buffer.toString());
    messenger.showSnackBar(SnackBar(content: Text('已导出：${file.path}')));
  }

  Future<void> _backup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await BackupService.buildBackupJson();
      final name =
          'campus_wallet_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
      final uri = await FilePicker.saveFile(
        dialogTitle: '保存备份文件',
        fileName: name,
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
      );
      if (uri != null) {
        messenger.showSnackBar(SnackBar(content: Text('已备份：$uri')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('备份失败：$e')));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: '选择备份文件',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (files.isEmpty) return;
      final bytes = await files.first.xFile.readAsBytes();
      final content = utf8.decode(bytes);
      if (content.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('读取文件失败')));
        return;
      }
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('恢复数据？'),
          content: const Text('恢复后将覆盖当前全部数据，且无法撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认恢复'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await BackupService.restoreFromJson(content);
      messenger.showSnackBar(const SnackBar(content: Text('恢复成功')));
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('恢复失败：$e')));
    }
  }

  Future<void> _clearAll(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空所有数据？'),
        content: const Text('将删除全部流水、预算与设置，且无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Dao.instance.clearAllData();
      messenger.showSnackBar(const SnackBar(content: Text('已清空')));
    }
  }
}