import 'package:flutter/material.dart';

class DoorStatusBanner extends StatefulWidget {
  final String doorStatus;
  final int cooldownSeconds;

  const DoorStatusBanner({
    super.key,
    required this.doorStatus,
    this.cooldownSeconds = 6,
  });

  @override
  State<DoorStatusBanner> createState() => _DoorStatusBannerState();
}

class _DoorStatusBannerState extends State<DoorStatusBanner>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didUpdateWidget(DoorStatusBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.doorStatus.isNotEmpty && oldWidget.doorStatus.isEmpty) {
      _controller?.dispose();
      _controller = AnimationController(
        vsync: this,
        duration: Duration(seconds: widget.cooldownSeconds),
      )..forward();
    } else if (widget.doorStatus.isEmpty) {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.doorStatus.isEmpty) return const SizedBox.shrink();

    final isEntry = widget.doorStatus.contains('Giriş');
    final color = isEntry ? Colors.green : Colors.orange.shade700;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: color,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isEntry ? Icons.check_circle : Icons.logout,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                widget.doorStatus,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (_controller != null)
          AnimatedBuilder(
            animation: _controller!,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: 1.0 - _controller!.value,
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 3,
              );
            },
          ),
      ],
    );
  }
}
