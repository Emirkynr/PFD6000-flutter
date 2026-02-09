import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../../ble/ble_manager.dart';
import '../scanner/managers/device_filter.dart';
import '../../services/widget_channel_service.dart';

/// Door picker page for widget configuration
/// Shows available BLE doors and allows selection for widget binding
class WidgetDoorPickerPage extends StatefulWidget {
  final int widgetId;
  final String? widgetType;

  const WidgetDoorPickerPage({
    super.key,
    required this.widgetId,
    this.widgetType,
  });

  @override
  State<WidgetDoorPickerPage> createState() => _WidgetDoorPickerPageState();
}

class _WidgetDoorPickerPageState extends State<WidgetDoorPickerPage> {
  final BleManager _bleManager = BleManager();
  List<DiscoveredDevice> _devices = [];
  StreamSubscription<List<DiscoveredDevice>>? _deviceSubscription;
  bool _isScanning = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
      _devices = [];
    });

    // Listen to device stream
    _deviceSubscription = _bleManager.devicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _devices = devices;
        });
      }
    });

    // Start scanning - NO manufacturerId param to use default Politeknik filter
    // BleManager already filters for [80,84] (PT) manufacturer data
    _bleManager.startScan();

    // Auto stop after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isScanning) {
        _stopScan();
      }
    });
  }

  void _stopScan() {
    _bleManager.stopScan();
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _rescan() {
    _bleManager.clearDevices();
    _startScan();
  }

  Future<void> _selectDoor(DiscoveredDevice device) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Extract door name using existing device filter
      final doorName = DeviceFilter.extractDeviceName(device);
      // Use device ID as identifier (unique per device)
      final doorIdentifier = device.id;

      debugPrint(
          'WidgetDoorPicker: Saving widgetId=${widget.widgetId} door=$doorName id=$doorIdentifier');

      // Save to Android via MethodChannel
      await WidgetChannelService().saveDoorConfig(
        widget.widgetId,
        doorName,
        doorIdentifier,
      );

      if (mounted) {
        // Show success toast
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$doorName widget\'a kaydedildi'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );

        // Wait a moment for toast to show, then close activity
        await Future.delayed(const Duration(milliseconds: 500));

        // Tell Android to finish the activity (not just pop Flutter nav)
        await WidgetChannelService().finishWidgetActivity();
      }
    } catch (e) {
      debugPrint('WidgetDoorPicker: Error saving: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    _bleManager.stopScan();
    _bleManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kapı Seç'),
        centerTitle: true,
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _rescan,
              tooltip: 'Yeniden Tara',
            ),
        ],
      ),
      body: Column(
        children: [
          // Header info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Widget ${widget.widgetId} için kapı seç',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.bluetooth_searching,
                      size: 16,
                      color: _isScanning
                          ? colorScheme.primary
                          : colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isScanning
                          ? 'Taranıyor... (${_devices.length} kapı bulundu)'
                          : '${_devices.length} kapı bulundu',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Device list
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isScanning
                              ? Icons.bluetooth_searching
                              : Icons.bluetooth_disabled,
                          size: 64,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning
                              ? 'Kapılar aranıyor...'
                              : 'Kapı bulunamadı',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (!_isScanning) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _rescan,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Yeniden Tara'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      final doorName = DeviceFilter.extractDeviceName(device);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.meeting_room,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          title: Text(
                            doorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'RSSI: ${device.rssi} dBm',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.outline,
                            ),
                          ),
                          trailing: _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: colorScheme.outline,
                                ),
                          onTap: _isSaving ? null : () => _selectDoor(device),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
