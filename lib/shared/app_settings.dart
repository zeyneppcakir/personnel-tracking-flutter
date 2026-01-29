import 'package:flutter/material.dart';

class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _langCode = 'tr'; // 'tr' | 'en'

  ThemeMode get themeMode => _themeMode;
  String get langCode => _langCode;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void setLang(String code) {
    if (_langCode == code) return;
    _langCode = code;
    notifyListeners();
  }
}
