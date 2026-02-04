/*import 'package:flutter/material.dart';

class DoorStatusBanner extends StatelessWidget {
  final String doorStatus;

  const DoorStatusBanner({
    super.key,
    required this.doorStatus,
  });

  @override
  Widget build(BuildContext context) {
    if (doorStatus.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.green,
      child: Text(
        doorStatus,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}*/
import 'package:flutter/material.dart';

class DoorStatusBanner extends StatelessWidget {
  final String doorStatus;

  const DoorStatusBanner({super.key, required this.doorStatus});

  @override
  Widget build(BuildContext context) {
    if (doorStatus.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.green,
      child: Text(
        doorStatus,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}

