/*import 'package:flutter/material.dart';

class EspNumberDisplay extends StatelessWidget {
  final String espNumber;

  const EspNumberDisplay({
    super.key,
    required this.espNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.security,
                color: Colors.blue.shade700,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'ESP Güvenlik Kodu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade300),
            ),
            child: Text(
              espNumber,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: espNumber == "Bağlantı yok" ? Colors.grey : Colors.blue.shade800,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            espNumber == "Bağlantı yok" 
                ? "BLE cihazına bağlanın" 
                : "Son yakalanan sayı",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}*/
import 'package:flutter/material.dart';

class EspNumberDisplay extends StatelessWidget {
  final String espNumber;

  const EspNumberDisplay({super.key, required this.espNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 8),
              Text('ESP Güvenlik Kodu',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade300),
            ),
            child: Text(
              espNumber,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: espNumber == "Bağlantı yok" ? Colors.grey : Colors.blue.shade800,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            espNumber == "Bağlantı yok" ? "BLE cihazına bağlanın" : "Son yakalanan sayı",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

