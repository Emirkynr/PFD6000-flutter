import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
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

  factory EntryResult.btOff() => const EntryResult(
        success: false,
        reason: EntryResultReason.btOff,
        message: 'Bluetooth kapalı',
      );

  factory EntryResult.permissionDenied() => const EntryResult(
        success: false,
        reason: EntryResultReason.permissionDenied,
        message: 'İzin verilmedi',
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
    debugPrint('');
    debugPrint('╔═══════════════════════════════════════════════════════════╗');
    debugPrint(
        '║          GATE ENTRY SERVICE - STARTING                     ║');
    debugPrint('╠═══════════════════════════════════════════════════════════╣');
    debugPrint('║ doorId: $doorIdentifier');
    debugPrint('╚═══════════════════════════════════════════════════════════╝');

    if (_disposed) {
      debugPrint('GateEntryService: ERROR - service disposed');
      return EntryResult.error('Servis kapatılmış');
    }

    // UPDATE: Section 5 - Permission & BT State Checks (Android 12+)
    debugPrint('GateEntryService: Checking Permissions & BT State...');

    // 1. Check Permissions
    bool permissionsGranted = false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Request/Check permissions loosely - allow if restricted/limited but try our best
      // Android 12+ (S+)
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();

      // Location (Pre-12 or if needed)
      final locationStatus = await Permission.location.request();

      debugPrint(
          'GateEntryService: Perms - Scan:$scanStatus, Connect:$connectStatus, Loc:$locationStatus');

      if (scanStatus.isGranted ||
          connectStatus.isGranted ||
          locationStatus.isGranted) {
        permissionsGranted = true;
      }
    } else {
      // iOS or other
      permissionsGranted = true;
    }

    if (!permissionsGranted) {
      debugPrint('GateEntryService: ERROR - Permissions denied');
      // We try to proceed anyway as some devices might be weird, but log it
      // return EntryResult.permissionDenied();
    }

    // 2. Check Bluetooth Adapter State
    final ble = FlutterReactiveBle();
    try {
      final status =
          await ble.statusStream.first.timeout(const Duration(seconds: 1));
      debugPrint('GateEntryService: BT Status: $status');
      if (status != BleStatus.ready) {
        debugPrint('GateEntryService: ERROR - Bluetooth not ready');
        return EntryResult.btOff();
      }
    } catch (e) {
      debugPrint('GateEntryService: WARN - Could not get BT status: $e');
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
    debugPrint(
        'GateEntryService: Step 2 - Scanning for device (${_scanTimeoutSeconds}s)');

    DiscoveredDevice? targetDevice;
    bool deviceFound = false;

    // Start scanning
    _bleManager.startScan();

    // Listen for devices and find our target
    _deviceSubscription = _bleManager.devicesStream.listen((devices) {
      debugPrint('GateEntryService: Stream update - ${devices.length} devices');
      for (final device in devices) {
        // Filter for Politeknik devices
        if (DeviceFilter.hasRawData5054(device)) {
          debugPrint(
              'GateEntryService: Politeknik device: ${device.id} (name: ${device.name})');
          if (device.id == doorIdentifier) {
            debugPrint('GateEntryService: ★ TARGET FOUND ★');
            targetDevice = device;
            deviceFound = true;
          }
        }
      }
    });

    // Wait for scan with periodic checks (faster detection)
    for (int i = 0; i < _scanTimeoutSeconds * 2; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (deviceFound && targetDevice != null) {
        debugPrint('GateEntryService: Device found after ${(i + 1) * 500}ms');
        break;
      }
    }

    // Stop scanning and cleanup subscription
    await _deviceSubscription?.cancel();
    await _bleManager.stopScan();
    _deviceSubscription = null;

    // Also check the stored list as fallback
    if (!deviceFound || targetDevice == null) {
      targetDevice = _bleManager.findDeviceById(doorIdentifier);
      if (targetDevice != null) {
        debugPrint('GateEntryService: Device found via findDeviceById');
        deviceFound = true;
      }
    }

    if (!deviceFound || targetDevice == null) {
      debugPrint('GateEntryService: ERROR - Device not found after scan');
      await _cleanup();
      return EntryResult.notFound();
    }

    debugPrint(
        'GateEntryService: Device confirmed: ${targetDevice!.name} (${targetDevice!.id})');

    // Step 3: Connect to device (includes discoverServices!)
    debugPrint(
        'GateEntryService: Step 3 - Connecting (${_connectTimeoutSeconds}s timeout)');
    try {
      final connected = await _connectionManager
          .connectToDevice(targetDevice!.id)
          .timeout(Duration(seconds: _connectTimeoutSeconds));

      if (!connected) {
        debugPrint('GateEntryService: ERROR - Connection failed');
        await _cleanup();
        return EntryResult.connectFail();
      }
      debugPrint('GateEntryService: Connection SUCCESSFUL');

      // Small delay for connection stabilization (same as scanner_page)
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 4: Send entry message
      debugPrint('GateEntryService: Step 4 - Sending entry message');
      final sendSuccess =
          await _messageSender.sendEntryMessage(cardBytes, targetDevice!);

      if (sendSuccess) {
        debugPrint('');
        debugPrint(
            '╔═══════════════════════════════════════════════════════════╗');
        debugPrint(
            '║             ★★★ SUCCESS - DOOR COMMAND SENT ★★★           ║');
        debugPrint(
            '╚═══════════════════════════════════════════════════════════╝');
        debugPrint('');
        await _connectionManager.disconnectFromDevice(targetDevice!.id);
        await _cleanup();
        return EntryResult.success();
      } else {
        debugPrint('GateEntryService: ERROR - sendEntryMessage returned false');
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
