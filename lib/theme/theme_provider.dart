import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  // ThemeMode _themeMode = ThemeMode.system; // OLD: system default
  ThemeMode _themeMode = ThemeMode.dark; // NEW: dark default

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      // We can't know for sure here without context, but strictly speaking this logic 
      // is usually handled by the Flutter framework. 
      // For toggle purpose, we mainly care if it's explicitly dark.
      return false; 
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}
