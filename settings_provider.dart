import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  late final SharedPreferences _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  int _preAlertMinutes = 15;
  bool _exactPromptShown = false;

  ThemeMode get themeMode => _themeMode;
  int get preAlertMinutes => _preAlertMinutes;
  bool get exactPromptShown => _exactPromptShown;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[_prefs.getInt('theme') ?? 0];
    _preAlertMinutes = _prefs.getInt('pre_alert') ?? 15;
    _exactPromptShown = _prefs.getBool('exact_prompt_shown') ?? false;
  }

  Future<void> setThemeMode(ThemeMode m) async {
    _themeMode = m;
    notifyListeners();
    await _prefs.setInt('theme', m.index);
  }

  Future<void> setPreAlertMinutes(int minutes) async {
    _preAlertMinutes = minutes;
    notifyListeners();
    await _prefs.setInt('pre_alert', minutes);
  }

  Future<void> markExactPromptShown() async {
    _exactPromptShown = true;
    await _prefs.setBool('exact_prompt_shown', true);
  }
}
