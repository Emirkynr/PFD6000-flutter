import 'package:flutter/material.dart';
import 'ui/scanner_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Politeknik BLE Reader',
      home: ScannerPage(),
    );
  }
}
