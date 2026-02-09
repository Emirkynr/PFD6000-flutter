import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../ble/ble_manager.dart';
import '../ble/ble_service.dart';
import '../ui/scanner/managers/message_sender.dart';
import '../ui/scanner/managers/card_manager.dart';

/// Service to handle door opening from widget
/// Performs quick BLE scan and sends Entry command
class WidgetDoorOpener {
  static const int _scanTimeoutSeconds = 5;

  final BleManager _bleManager = BleManager();
  late final BleService _bleService;
  late final MessageSender _messageSender;

  StreamSubscription<List<DiscoveredDevice>>? _deviceSubscription;
  Timer? _timeoutTimer;

  WidgetDoorOpener() {
    _bleService = BleService();
    _messageSender = MessageSender(bleService: _bleService);
  }

  /// Attempt to open door by identifier
  /// Returns true if command was sent successfully
  Future<bool> openDoor(String doorIdentifier) async {
    debugPrint('WidgetDoorOpener: Attempting to open door: $doorIdentifier');

    DiscoveredDevice? targetDevice;

    // Listen for devices
    _deviceSubscription = _bleManager.devicesStream.listen((devices) {
      // Try to find the target device by ID
      for (final device in devices) {
        if (device.id == doorIdentifier) {
          targetDevice = device;
          debugPrint('WidgetDoorOpener: Found target device!');
          _finishScan();
          break;
        }
      }
    });

    // Start scan - use default Politeknik filter (no manufacturerId)
    debugPrint('WidgetDoorOpener: Starting BLE scan...');
    _bleManager.startScan();

    // Set timeout
    _timeoutTimer = Timer(Duration(seconds: _scanTimeoutSeconds), () {
      debugPrint('WidgetDoorOpener: Scan timeout');
      _finishScan();
    });

    // Wait for scan to complete
    await Future.delayed(Duration(seconds: _scanTimeoutSeconds + 1));

    // Check if device was found
    if (targetDevice == null) {
      // Try one more time from current device list
      targetDevice = _bleManager.findDeviceById(doorIdentifier);
    }

    if (targetDevice == null) {
      debugPrint('WidgetDoorOpener: Device not found');
      await _cleanup();
      return false;
    }

    // Device found - send entry command
    try {
      debugPrint('WidgetDoorOpener: Connecting and sending Entry command...');

      // Get saved card bytes using CardManager
      final cardBytes = await CardManager.getConfiguredCardNumber();
      if (cardBytes.isEmpty) {
        debugPrint('WidgetDoorOpener: No card configured');
        await _cleanup();
        return false;
      }

      // Connect to device
      await _bleService.connectToDevice(targetDevice!.id);

      // Wait a bit for connection to stabilize
      await Future.delayed(const Duration(milliseconds: 500));

      // Send entry message
      final success =
          await _messageSender.sendEntryMessage(cardBytes, targetDevice!);

      debugPrint('WidgetDoorOpener: Entry command result: $success');

      // Disconnect after sending
      await Future.delayed(const Duration(milliseconds: 300));
      await _bleService.disconnect();

      await _cleanup();
      return success;
    } catch (e) {
      debugPrint('WidgetDoorOpener: Error sending command: $e');
      await _cleanup();
      return false;
    }
  }

  void _finishScan() {
    _timeoutTimer?.cancel();
    _bleManager.stopScan();
  }

  Future<void> _cleanup() async {
    _timeoutTimer?.cancel();
    await _deviceSubscription?.cancel();
    await _bleManager.stopScan();
    await _bleManager.dispose();
  }

  Future<void> dispose() async {
    await _cleanup();
  }
}
