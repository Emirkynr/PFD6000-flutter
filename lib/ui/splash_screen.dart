import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'scanner_page.dart';
import '../ble/ble_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  BleManager? _bleManager; // BLE manager for pre-scanning

  @override
  void initState() {
    super.initState();

    // Start BLE pre-scanning to warm up device discovery
    _bleManager = BleManager();
    _bleManager!.startScan();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000), // 3 second animation
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward().then((_) {
       // Add 1 second delay after animation for total 4 seconds
       Future.delayed(const Duration(milliseconds: 1000), () {
         _navigateToHome();
       });
    });
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const ScannerPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0); // Slide from bottom
          const end = Offset.zero; // To center
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          // You can combine with Fade
          return FadeTransition(
            opacity: animation,
            child: child, // Or SlideTransition if preferred, but Fade is smoother for top-level replacement
          );
        },
        transitionDuration: const Duration(milliseconds: 300), // Reduced from 800ms
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _bleManager?.stopScan(); // Stop pre-scan before disposal
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Theme aware background
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFF1976D2);
    final contentColor = Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bluetooth_audio, // Or bluetooth_connected
                        size: 80,
                        color: contentColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Title
                    Text(
                      'POLITEKNIK BGS',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: contentColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle
                    Text(
                      'Bluetooth Geçiş Sistemi',
                      style: TextStyle(
                        fontSize: 14,
                        color: contentColor.withOpacity(0.8),
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
