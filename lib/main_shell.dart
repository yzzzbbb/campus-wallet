import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/data/dao.dart';
import 'core/logic/alert_logic.dart';
import 'core/logic/finance_math.dart';
import 'features/budget/budget_page.dart';
import 'features/home/home_page.dart';
import 'features/settings/settings_page.dart';
import 'features/stats/stats_page.dart';
import 'features/transaction/transaction_edit_page.dart';
import 'features/transaction/transaction_list_page.dart';
import 'state/budget_provider.dart';
import 'state/notification_service.dart';
import 'state/settings_provider.dart';
import 'state/transaction_provider.dart';
import 'state/widget_sync.dart';

/// 主壳：底部导航 4 Tab（首页 / 流水 / 统计 / 我的）
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBudgetAlert();
      _syncWidget();
    });
  }

  /// 同步倒计时摘要到桌面小组件（Android）
  Future<void> _syncWidget() async {
    if (!mounted) return;
    final budget = context.read<BudgetProvider>();
    if (!budget.loaded) return;
    final setting = budget.setting;
    if (setting.allowanceAmountCents <= 0) return;
    final tx = context.read<TransactionProvider>();
    final monthKey = FinanceMath.monthKey(DateTime.now());
    final spent = await tx.monthExpenseCents(monthKey);
    final days = budget.daysToNextPay;
    final remaining = budget.effectiveMonthlyBudgetCents - spent;
    final daily = FinanceMath.dailyAvailable(
      remainingCents: remaining,
      daysToNextPay: days,
    );
    await WidgetSync.syncSummary(
      days: days,
      remainingCents: remaining,
      dailyCents: (daily * 100).round(),
      monthExpenseCents: spent,
    );
  }

  /// 打开应用时检查预算使用率并本地通知（开关在设置页）
  Future<void> _checkBudgetAlert() async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    if (!settings.budgetAlertEnabled) return;
    final budget = context.read<BudgetProvider>();
    if (!budget.loaded || !budget.setting.isConfigured) return;
    final tx = context.read<TransactionProvider>();
    final monthKey = FinanceMath.monthKey(DateTime.now());
    final spent = await tx.monthExpenseCents(monthKey);
    final effective = budget.effectiveMonthlyBudgetCents;
    if (effective <= 0) return;
    final usage = spent / effective;
    final level = AlertLogic.levelForUsage(usage);
    final today = AlertLogic.dateKey(DateTime.now());
    final lastDate =
        await Dao.instance.getSetting('last_budget_alert_date') ?? '';
    final lastLevel =
        await Dao.instance.getSetting('last_budget_alert_level') ?? '';
    if (!AlertLogic.shouldAlert(
      lastAlertDate: lastDate,
      lastLevel: lastLevel,
      today: today,
      newLevel: level,
    )) {
      return;
    }
    await NotificationService.instance.init();
    await NotificationService.instance.showBudgetAlert(usage: usage);
    await Dao.instance.setSetting('last_budget_alert_date', today);
    await Dao.instance.setSetting('last_budget_alert_level', level);
  }

  void _openTransactionEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const TransactionEditPage(),
      ),
    );
  }

  void _openBudget() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BudgetPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(
            onAddTransaction: _openTransactionEditor,
            onOpenBudget: _openBudget,
          ),
          const TransactionListPage(),
          const StatsPage(),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '流水',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}