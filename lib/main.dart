import 'package:flutter/material.dart';
import 'ui/scanner_page.dart';
import 'ui/splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
  
  // Static accessor for ThemeProvider to easily toggle from anywhere
  static ThemeProvider of(BuildContext context) {
    return context.findAncestorStateOfType<_MyAppState>()!._themeProvider;
  }
}

class _MyAppState extends State<MyApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeProvider,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'POLITEKNIK BGS',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _themeProvider.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
