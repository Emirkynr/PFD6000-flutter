import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../ble/ble_manager.dart';
import '../ble/ble_service.dart';
import '../ui/scanner/managers/connection_manager.dart';
import '../ui/scanner/managers/message_sender.dart';
import '../ui/scanner/managers/card_manager.dart';
import '../ui/scanner/managers/device_filter.dart';

/// Result codes for gate entry operations
enum EntryResultReason {
  success,
  notFound,
  noCard,
  btOff,
  permissionDenied,
  connectFail,
  writeFail,
  timeout,
  unknown,
}

/// Result of a gate entry attempt
class EntryResult {
  final bool success;
  final EntryResultReason reason;
  final String message;

  const EntryResult({
    required this.success,
    required this.reason,
    required this.message,
  });

  factory EntryResult.success() => const EntryResult(
        success: true,
        reason: EntryResultReason.success,
        message: 'Komut gönderildi',
      );

  factory EntryResult.notFound() => const EntryResult(
        success: false,
        reason: EntryResultReason.notFound,
        message: 'Kapı tespit edilemedi',
      );

  factory EntryResult.noCard() => const EntryResult(
        success: false,
        reason: EntryResultReason.noCard,
        message: 'Kart yapılandırılmamış',
      );

  factory EntryResult.connectFail() => const EntryResult(
        success: false,
        reason: EntryResultReason.connectFail,
        message: 'Bağlantı kurulamadı',
      );

  factory EntryResult.writeFail() => const EntryResult(
        success: false,
        reason: EntryResultReason.writeFail,
        message: 'Komut gönderilemedi',
      );

  factory EntryResult.timeout() => const EntryResult(
        success: false,
        reason: EntryResultReason.timeout,
        message: 'Zaman aşımı',
      );

  factory EntryResult.error(String msg) => EntryResult(
        success: false,
        reason: EntryResultReason.unknown,
        message: msg,
      );
}

/// Shared service for gate entry - used by both main app button and widget
/// Uses the same BLE code path: ConnectionManager + MessageSender
class GateEntryService {
  static const int _scanTimeoutSeconds = 8;
  static const int _connectTimeoutSeconds = 5;

  final BleManager _bleManager = BleManager();
  final BleService _bleService = BleService();
  late final ConnectionManager _connectionManager;
  late final MessageSender _messageSender;

  final Map<String, bool> _deviceConnections = {};
  StreamSubscription<List<DiscoveredDevice>>? _deviceSubscription;
  Timer? _scanTimer;
  bool _disposed = false;

  GateEntryService() {
    _connectionManager = ConnectionManager(
      bleService: _bleService,
      deviceConnections: _deviceConnections,
    );
    _messageSender = MessageSender(bleService: _bleService);
  }

  /// Attempt to open a door by its identifier (device ID)
  /// This is the SAME code path as the main "Giriş Yap" button
  Future<EntryResult> enterGate(String doorIdentifier) async {
    debugPrint('GateEntryService: START enterGate doorId=$doorIdentifier');

    if (_disposed) {
      debugPrint('GateEntryService: ERROR - service disposed');
      return EntryResult.error('Servis kapatılmış');
    }

    // Step 1: Get card bytes
    debugPrint('GateEntryService: Step 1 - Getting card bytes');
    final cardBytes = await CardManager.getConfiguredCardNumber();
    if (cardBytes.isEmpty) {
      debugPrint('GateEntryService: ERROR - No card configured');
      return EntryResult.noCard();
    }
    debugPrint('GateEntryService: Card bytes OK (${cardBytes.length} bytes)');

    // Step 2: Scan for the device
    debugPrint('GateEntryService: Step 2 - Scanning for device');
    DiscoveredDevice? targetDevice;
    final completer = Completer<DiscoveredDevice?>();

    _deviceSubscription = _bleManager.devicesStream.listen((devices) {
      debugPrint('GateEntryService: Scan found ${devices.length} devices');
      for (final device in devices) {
        // Filter for Politeknik devices
        if (DeviceFilter.hasRawData5054(device)) {
          debugPrint('GateEntryService: Found Politeknik device: ${device.id}');
          if (device.id == doorIdentifier) {
            debugPrint('GateEntryService: TARGET FOUND: ${device.id}');
            targetDevice = device;
            if (!completer.isCompleted) {
              completer.complete(device);
            }
          }
        }
      }
    });

    // Start scanning
    _bleManager.startScan();

    // Set scan timeout
    _scanTimer = Timer(Duration(seconds: _scanTimeoutSeconds), () {
      debugPrint(
          'GateEntryService: Scan timeout after $_scanTimeoutSeconds seconds');
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    // Wait for device or timeout
    targetDevice = await completer.future;

    // Stop scanning
    await _bleManager.stopScan();
    await _deviceSubscription?.cancel();
    _scanTimer?.cancel();

    // Check if device was found
    if (targetDevice == null) {
      // Last chance - check in bleManager's current list
      targetDevice = _bleManager.findDeviceById(doorIdentifier);
    }

    if (targetDevice == null) {
      debugPrint('GateEntryService: ERROR - Device not found');
      await _cleanup();
      return EntryResult.notFound();
    }

    debugPrint('GateEntryService: Device found, proceeding with connection');

    // Step 3: Connect to device (includes discoverServices!)
    debugPrint('GateEntryService: Step 3 - Connecting to device');
    try {
      final connected = await _connectionManager
          .connectToDevice(targetDevice!.id)
          .timeout(Duration(seconds: _connectTimeoutSeconds));

      if (!connected) {
        debugPrint('GateEntryService: ERROR - Connection failed');
        await _cleanup();
        return EntryResult.connectFail();
      }
      debugPrint('GateEntryService: Connection successful');

      // Small delay for connection stabilization (same as scanner_page)
      await Future.delayed(const Duration(milliseconds: 200));

      // Step 4: Send entry message
      debugPrint('GateEntryService: Step 4 - Sending entry message');
      final sendSuccess =
          await _messageSender.sendEntryMessage(cardBytes, targetDevice!);

      if (sendSuccess) {
        debugPrint('GateEntryService: SUCCESS - Entry command sent');
        await _connectionManager.disconnectFromDevice(targetDevice!.id);
        await _cleanup();
        return EntryResult.success();
      } else {
        debugPrint('GateEntryService: ERROR - Write failed');
        await _connectionManager.disconnectFromDevice(targetDevice!.id);
        await _cleanup();
        return EntryResult.writeFail();
      }
    } on TimeoutException {
      debugPrint('GateEntryService: ERROR - Connection timeout');
      await _cleanup();
      return EntryResult.timeout();
    } catch (e) {
      debugPrint('GateEntryService: ERROR - Exception: $e');
      await _cleanup();
      return EntryResult.error('Hata: $e');
    }
  }

  Future<void> _cleanup() async {
    debugPrint('GateEntryService: Cleanup');
    _scanTimer?.cancel();
    await _deviceSubscription?.cancel();
    await _bleManager.stopScan();
  }

  Future<void> dispose() async {
    debugPrint('GateEntryService: Dispose');
    _disposed = true;
    await _cleanup();
    await _bleManager.dispose();
    _bleService.dispose();
  }
}
