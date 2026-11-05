import 'package:flutter/material.dart';

/// 全局配色（契约）
class AppColors {
  static const primary = Color(0xFF10B981);
  static const expense = Color(0xFFE53935);
  static const income = Color(0xFF43A047);
  static const warn = Color(0xFFFFB300); // 配额 80%~100%
  static const over = Color(0xFFE53935); // 超支
}

/// 亮/暗主题（契约）
class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness b) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: b,
        ),
        scaffoldBackgroundColor:
            b == Brightness.light ? const Color(0xFFF6F7F9) : const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      );
}