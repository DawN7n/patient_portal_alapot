import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static Future<void> load(SharedPreferences prefs) async {
    final isDarkMode = prefs.getBool('dark_mode') ?? false;

    mode.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> toggle(SharedPreferences prefs) async {
    final nextMode = mode.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;

    mode.value = nextMode;

    await prefs.setBool(
      'dark_mode',
      nextMode == ThemeMode.dark,
    );
  }
}
