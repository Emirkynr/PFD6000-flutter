import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'scanner_page.dart';
import '../ble/ble_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  BleManager? _bleManager;
  bool _showFirstLogo = true;

  @override
  void initState() {
    super.initState();

    // Start BLE pre-scanning to warm up device discovery
    _bleManager = BleManager();
    _bleManager!.startScan();

    _checkSkipSplash();
  }

  Future<void> _checkSkipSplash() async {
    final prefs = await SharedPreferences.getInstance();
    final lastLaunch = prefs.getInt('last_launch_ms') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 5 dakika icinde tekrar acilirsa splash'i atla
    if (now - lastLaunch < 300000) {
      await prefs.setInt('last_launch_ms', now);
      if (mounted) _navigateToHome();
      return;
    }

    await prefs.setInt('last_launch_ms', now);
    _startAnimation();
  }

  void _startAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Tek animasyon: ilk logo fade in, sonra ikinci logo, sonra gecis
    _controller!.forward().then((_) {
      if (!mounted) return;
      setState(() {
        _showFirstLogo = false;
      });
      _controller!.reset();
      _controller!.forward().then((_) {
        if (!mounted) return;
        _navigateToHome();
      });
    });
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ScannerPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _bleManager?.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    const backgroundColor = Color(0xFF121212);
    const contentColor = Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 100,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1.0)
                          .animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _showFirstLogo
                    ? ClipRRect(
                        key: const ValueKey('enka'),
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/enka_full_logo.png',
                          width: 300,
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                      )
                    : ClipRRect(
                        key: const ValueKey('politeknik'),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          color: Colors.white,
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 200,
                            height: 80,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 48),
            const Text(
              'ENKA GS',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: contentColor,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'POLITEKNIK - ENKA',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: contentColor.withOpacity(0.8),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bluetooth Geçiş Sistemi',
              style: TextStyle(
                fontSize: 14,
                color: contentColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
