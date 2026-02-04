import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'device_list_tile.dart';

class DeviceList extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: devices.isEmpty ? 1 : devices.length,
      itemBuilder: (context, index) {
        if (devices.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bluetooth_searching, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 24),
                  Text(
                    'Cihaz bulunamadı',
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.grey.shade700
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Yakındaki BLE cihazları taramak için aşağı çekin',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        
        final device = devices[index];
        final isConnected = deviceConnections[device.id] ?? false;
        return DeviceListTile(
          device: device,
          isConnected: isConnected,
          buttonsDisabled: buttonsDisabled,
          onEntry: () => onEntry(device.id),
          onExit: () => onExit(device.id),
          onTest: () => onTest(device),
          onCardConfig: () => onCardConfig(device.id),
        );
      },
    );
  }
}