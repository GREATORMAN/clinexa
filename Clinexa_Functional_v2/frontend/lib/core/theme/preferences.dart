import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
class AppPreferences {
  static Future<bool> Function()? beforeNavigate;
  static final mode = ValueNotifier<ThemeMode>(ThemeMode.dark);
  static final reducedMotion = ValueNotifier<bool>(false);
  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    mode.value = p.getBool('clinexa_light_mode') == true ? ThemeMode.light : ThemeMode.dark;
    reducedMotion.value = p.getBool('clinexa_reduced_motion') ?? false;
  }
  static Future<void> toggleTheme() async {
    mode.value = mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final p = await SharedPreferences.getInstance();
    await p.setBool('clinexa_light_mode', mode.value == ThemeMode.light);
  }
  static Future<void> setMotion(bool value) async {
    reducedMotion.value = value;
    final p = await SharedPreferences.getInstance();
    await p.setBool('clinexa_reduced_motion', value);
  }
}
