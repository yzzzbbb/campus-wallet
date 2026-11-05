import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'main_shell.dart';
import 'state/budget_provider.dart';
import 'state/category_provider.dart';
import 'state/recurring_bills_provider.dart';
import 'state/settings_provider.dart';
import 'state/transaction_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CampusWalletApp());
}

class CampusWalletApp extends StatefulWidget {
  const CampusWalletApp({super.key});

  @override
  State<CampusWalletApp> createState() => _CampusWalletAppState();
}

class _CampusWalletAppState extends State<CampusWalletApp> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<BudgetProvider>().load());
    unawaited(context.read<SettingsProvider>().load());
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => RecurringBillsProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: '生活费账本',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          home: const MainShell(),
        ),
      ),
    );
  }
}