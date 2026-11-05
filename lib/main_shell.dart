import 'package:flutter/material.dart';

import 'features/budget/budget_page.dart';
import 'features/home/home_page.dart';
import 'features/settings/settings_page.dart';
import 'features/stats/stats_page.dart';
import 'features/transaction/transaction_edit_page.dart';
import 'features/transaction/transaction_list_page.dart';

/// 主壳：底部导航 4 Tab（首页 / 流水 / 统计 / 我的）
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

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