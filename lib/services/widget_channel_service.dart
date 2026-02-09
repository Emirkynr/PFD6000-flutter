import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'gate_entry_service.dart';

/// Service for Flutter <-> Android Widget communication
/// Handles openDoor, configureDoor, and widget state queries
class WidgetChannelService {
  static const String _channelName = 'enka_gs_widget';
  static final MethodChannel _channel = MethodChannel(_channelName);

  // Callback for configuration flow (needs Navigator)
  Function(int widgetId, String? widgetType)? onConfigureDoor;

  // Singleton pattern
  static final WidgetChannelService _instance =
      WidgetChannelService._internal();
  factory WidgetChannelService() => _instance;

  WidgetChannelService._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
    debugPrint('WidgetChannelService: Handler registered');
  }

  /// Initialize the service - call from main.dart
  void init({
    required Function(int widgetId, String? widgetType) onConfigureDoor,
  }) {
    this.onConfigureDoor = onConfigureDoor;
    debugPrint('WidgetChannelService: Initialized with callbacks');
  }

  /// Handle incoming calls from Android
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('WidgetChannelService: Received method call: ${call.method}');

    switch (call.method) {
      case 'openDoor':
        return await _handleOpenDoor(call);

      case 'configureDoor':
        final args = Map<String, dynamic>.from(call.arguments);
        final widgetId = args['widgetId'] as int;
        final widgetType = args['widgetType'] as String?;
        debugPrint('WidgetChannelService: configureDoor widgetId=$widgetId');
        onConfigureDoor?.call(widgetId, widgetType);
        return null;

      case 'getWidgetState':
        final widgetId = call.arguments as int;
        return null;

      default:
        throw PlatformException(
          code: 'NOT_IMPLEMENTED',
          message: 'Method ${call.method} not implemented',
        );
    }
  }

  /// Handle openDoor - uses GateEntryService for actual BLE work
  /// Returns TRUE only after BLE command is ACTUALLY sent
  Future<bool> _handleOpenDoor(MethodCall call) async {
    final args = Map<String, dynamic>.from(call.arguments);
    final widgetId = args['widgetId'] as int;
    final doorIdentifier = args['doorIdentifier'] as String;
    final doorName = args['doorName'] as String;

    debugPrint('WidgetChannelService: openDoor START');
    debugPrint('  widgetId: $widgetId');
    debugPrint('  doorIdentifier: $doorIdentifier');
    debugPrint('  doorName: $doorName');

    try {
      // Use GateEntryService for actual BLE work
      final service = GateEntryService();
      final result = await service.enterGate(doorIdentifier);

      debugPrint('WidgetChannelService: openDoor RESULT');
      debugPrint('  success: ${result.success}');
      debugPrint('  reason: ${result.reason}');
      debugPrint('  message: ${result.message}');

      // Cleanup
      await service.dispose();

      // Return actual success status
      return result.success;
    } catch (e) {
      debugPrint('WidgetChannelService: openDoor ERROR: $e');
      return false;
    }
  }

  /// Notify Android to update widget UI
  Future<void> updateWidget(int widgetId, String doorName) async {
    try {
      await _channel.invokeMethod('updateWidget', {
        'widgetId': widgetId,
        'doorName': doorName,
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to update widget: ${e.message}');
    }
  }

  /// Notify Android that door was not found
  Future<void> showNotFound(int widgetId) async {
    try {
      await _channel.invokeMethod('showNotFound', {
        'widgetId': widgetId,
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to show not found: ${e.message}');
    }
  }

  /// Save door configuration for a widget (called after door picker selection)
  Future<void> saveDoorConfig(
      int widgetId, String doorName, String doorIdentifier) async {
    try {
      await _channel.invokeMethod('saveDoorConfig', {
        'widgetId': widgetId,
        'doorName': doorName,
        'doorIdentifier': doorIdentifier,
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to save door config: ${e.message}');
    }
  }

  /// Tell Android to finish the widget activity (close the app after config)
  Future<void> finishWidgetActivity() async {
    try {
      await _channel.invokeMethod('finishActivity');
    } on PlatformException catch (e) {
      debugPrint('Failed to finish activity: ${e.message}');
    }
  }
}
