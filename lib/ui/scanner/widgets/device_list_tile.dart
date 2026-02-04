import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../managers/device_filter.dart';

/// BLE cihaz listesi için optimize edilmiş liste elemanı widget'ı
/// ManufacturerData'nın farklı tiplerini (Uint8List, Map) güvenli şekilde handle eder
class DeviceListTile extends StatelessWidget {
  final DiscoveredDevice device;
  final bool isConnected;
  final bool buttonsDisabled;
  final VoidCallback onEntry;
  final VoidCallback onExit;
  final VoidCallback onTest;
  final VoidCallback onCardConfig;

  const DeviceListTile({
    super.key,
    required this.device,
    required this.isConnected,
    required this.buttonsDisabled,
    required this.onEntry,
    required this.onExit,
    required this.onTest,
    required this.onCardConfig,
  });

  /// Manufacturer data'yı güvenli bir şekilde string'e çevir
  String _getManufacturerDataString(dynamic manufacturerData) {
    try {
      if (manufacturerData == null) return 'N/A';

      if (manufacturerData is Uint8List) {
        if (manufacturerData.isEmpty) return 'N/A';
        return String.fromCharCodes(manufacturerData);
      }

      if (manufacturerData is Map<int, List<int>>) {
        if (manufacturerData.isEmpty) return 'N/A';
        final entries = manufacturerData.entries.toList();
        if (entries.isNotEmpty) {
          return String.fromCharCodes(entries.first.value);
        }
      }

      if (manufacturerData is Map) {
        if (manufacturerData.isEmpty) return 'N/A';
        final entries = manufacturerData.entries.toList();
        if (entries.isNotEmpty) {
          final value = entries.first.value;
          if (value is List<int>) {
            return String.fromCharCodes(value);
          }
          if (value is Uint8List) {
            return String.fromCharCodes(value);
          }
        }
      }

      return 'N/A';
    } catch (e) {
      debugPrint('ManufacturerData parse error: $e');
      return 'Parse Error';
    }
  }

  /// Manufacturer Code'u hex formatında al (0x%04X)
  String _getManufacturerCode(dynamic manufacturerData) {
    try {
      if (manufacturerData is Map) {
        for (var entry in manufacturerData.entries) {
          return '0x${entry.key.toRadixString(16).padLeft(4, '0').toUpperCase()}';
        }
      }
      return 'N/A';
    } catch (e) {
      return 'Error';
    }
  }

  /// Raw data'yı hex formatında al (%02X)
  String _getRawDataHex(dynamic manufacturerData) {
    try {
      if (manufacturerData is Uint8List) {
        if (manufacturerData.isEmpty) return 'N/A';
        return '0x${manufacturerData.map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' 0x')}';
      } else if (manufacturerData is Map<int, List<int>>) {
        for (var entry in manufacturerData.entries) {
          if (entry.value is List<int> && entry.value.isNotEmpty) {
            return '0x${(entry.value as List<int>).map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' 0x')}';
          }
        }
      } else if (manufacturerData is Map) {
        for (var entry in manufacturerData.entries) {
          if (entry.value is List<int> && entry.value.isNotEmpty) {
            return '0x${(entry.value as List<int>).map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' 0x')}';
          }
        }
      }
      return 'N/A';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Raw data'yı byte array olarak al
  String _getRawDataBytes(dynamic manufacturerData) {
    try {
      if (manufacturerData is Uint8List) {
        if (manufacturerData.isEmpty) return 'N/A';
        return '[${manufacturerData.map((byte) => byte.toString()).join(', ')}]';
      } else if (manufacturerData is Map<int, List<int>>) {
        for (var entry in manufacturerData.entries) {
          if (entry.value is List<int> && entry.value.isNotEmpty) {
            return '[${(entry.value as List<int>).map((byte) => byte.toString()).join(', ')}]';
          }
        }
      } else if (manufacturerData is Map) {
        for (var entry in manufacturerData.entries) {
          if (entry.value is List<int> && entry.value.isNotEmpty) {
            return '[${(entry.value as List<int>).map((byte) => byte.toString()).join(', ')}]';
          }
        }
      }
      return 'N/A';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Data uzunluğunu al
  String _getDataLength(dynamic manufacturerData) {
    try {
      if (manufacturerData is Uint8List) {
        return manufacturerData.length.toString();
      } else if (manufacturerData is Map) {
        for (var entry in manufacturerData.entries) {
          if (entry.value is List<int>) {
            return (entry.value as List<int>).length.toString();
          }
        }
      }
      return '0';
    } catch (e) {
      return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Raw data'dan cihaz adını çıkar
    final deviceName = DeviceFilter.extractDeviceName(device);
    final manufacturerString = _getManufacturerDataString(device.manufacturerData);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: isConnected ? 4 : 2,
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: isConnected ? Colors.green : Theme.of(context).colorScheme.primary,
            ),
            title: Text(deviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: ${device.id}'),
                Text('RSSI: ${device.rssi} dBm'),
                if (manufacturerString != 'N/A') ...[
//                  Text('Manufacturer Code: ${_getManufacturerCode(device.manufacturerData)}'),
                  Text('Raw Data (HEX): ${_getRawDataHex(device.manufacturerData)}'),
//                  Text('Raw Data (Bytes): ${_getRawDataBytes(device.manufacturerData)}'),
                  Text('Data Length: ${_getDataLength(device.manufacturerData)} bytes'),
                ],
              ],
            ),
            trailing: Text(isConnected ? 'CONNECTED' : 'READY'),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: buttonsDisabled ? null : onEntry,
                    icon: const Icon(Icons.login),
                    label: const Text('Entry'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: buttonsDisabled ? null : onExit,
                    icon: const Icon(Icons.logout),
                    label: const Text('Exit'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTest,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Raw Data Test'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: buttonsDisabled ? null : onCardConfig,
                icon: const Icon(Icons.credit_card),
                label: const Text('Kart Konfigürasyonu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
