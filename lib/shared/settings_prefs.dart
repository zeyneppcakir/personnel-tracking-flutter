import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class SettingsPrefs {
  static const _kTheme = 'theme_mode';
  static const _kLang = 'lang_code';

  static Future<void> saveTheme(ThemeMode mode) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kTheme, mode.name); // system/light/dark
  }

  static Future<ThemeMode> loadTheme() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString(_kTheme);
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> saveLang(String code) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLang, code);
  }

  static Future<String> loadLang() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kLang) ?? 'tr';
  }
}
