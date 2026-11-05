import 'package:flutter/material.dart';

import '../core/data/dao.dart';

/// UI 设置状态（契约：禁止改公开方法签名）
class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final v = await Dao.instance.getSetting('theme_mode');
    if (v == 'light') {
      _themeMode = ThemeMode.light;
    } else if (v == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    _themeMode = m;
    await Dao.instance.setSetting('theme_mode', m.name);
    notifyListeners();
  }
}