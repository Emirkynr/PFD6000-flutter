import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'device_list_tile.dart';

class DeviceList extends StatefulWidget {
  final List<DiscoveredDevice> devices;
  final Map<String, bool> deviceConnections;
  final bool buttonsDisabled;
  final void Function(String deviceId) onEntry;
  final void Function(String deviceId) onExit;
  final void Function(DiscoveredDevice device) onTest;
  final void Function(String deviceId) onCardConfig;

  const DeviceList({
    super.key,
    required this.devices,
    required this.deviceConnections,
    required this.buttonsDisabled,
    required this.onEntry,
    required this.onExit,
    required this.onTest,
    required this.onCardConfig,
  });

  @override
  State<DeviceList> createState() => _DeviceListState();
}

class _DeviceListState extends State<DeviceList> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.devices.isEmpty ? 1 : widget.devices.length,
      itemBuilder: (context, index) {
        if (widget.devices.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: Icon(
                      Icons.bluetooth_searching,
                      size: 104,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Cihaz bulunamadı',
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold, 
                      color: Theme.of(context).colorScheme.onSurface
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Yakındaki BLE cihazları taramak için aşağı çekin',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        
        final device = widget.devices[index];
        final isConnected = widget.deviceConnections[device.id] ?? false;
        return DeviceListTile(
          device: device,
          isConnected: isConnected,
          buttonsDisabled: widget.buttonsDisabled,
          onEntry: () => widget.onEntry(device.id),
          onExit: () => widget.onExit(device.id),
          onTest: () => widget.onTest(device),
          onCardConfig: () => widget.onCardConfig(device.id),
        );
      },
    );
  }
}