import 'package:flutter/material.dart';
import 'ui/scanner_page.dart';
import 'ui/splash_screen.dart';
import 'ui/widget_config/widget_door_picker_page.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'services/widget_channel_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  final WidgetChannelService _widgetChannelService = WidgetChannelService();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initWidgetChannel();
  }

  void _initWidgetChannel() {
    _widgetChannelService.init(
      onConfigureDoor: (widgetId, widgetType) {
        // Navigate to door picker
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => WidgetDoorPickerPage(
              widgetId: widgetId,
              widgetType: widgetType,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeProvider,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'ENKA GS',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _themeProvider.themeMode,
          home: const SplashScreen(),
          routes: {
            '/widget-config': (context) {
              // Get widgetId from arguments
              final args = ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
              return WidgetDoorPickerPage(
                widgetId: args?['widgetId'] ?? 0,
                widgetType: args?['widgetType'],
              );
            },
          },
        );
      },
    );
  }
}
