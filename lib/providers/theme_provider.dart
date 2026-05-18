import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
    loadFingerprintPreference();
  }

  // ── Load saved theme from device ─────────────────────────────
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme_mode') ?? 'system';
    _themeMode = _parseThemeMode(savedTheme);
    notifyListeners();
  }

  // ── Toggle between light and dark ────────────────────────────
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    await _saveTheme();
    notifyListeners();
  }

  // ── Set specific theme mode ───────────────────────────────────
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _saveTheme();
    notifyListeners();
  }

  // ── Save theme to device ─────────────────────────────────────
  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    String themeString = 'system';
    if (_themeMode == ThemeMode.light) themeString = 'light';
    if (_themeMode == ThemeMode.dark) themeString = 'dark';
    await prefs.setString('theme_mode', themeString);
  }

  // ── Fingerprint lock preference ──────────────────────────────
  bool _fingerprintEnabled = false;

  bool get fingerprintEnabled => _fingerprintEnabled;

  Future<void> loadFingerprintPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _fingerprintEnabled = prefs.getBool('fingerprint_enabled') ?? false;
    notifyListeners();
  }

  Future<void> setFingerprintEnabled(bool value) async {
    _fingerprintEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fingerprint_enabled', value);
    notifyListeners();
  }

  // ── Helper to parse string to ThemeMode ──────────────────────
  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}