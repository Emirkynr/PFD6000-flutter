import 'dart:async';
import 'package:flutter/services.dart';

/// Service for Flutter <-> Android Widget communication
/// Handles openDoor, configureDoor, and widget state queries
class WidgetChannelService {
  static const String _channelName = 'enka_gs_widget';
  static final MethodChannel _channel = MethodChannel(_channelName);

  // Callback handlers
  Function(int widgetId, String doorIdentifier, String doorName)? onOpenDoor;
  Function(int widgetId, String? widgetType)? onConfigureDoor;

  // Singleton pattern
  static final WidgetChannelService _instance =
      WidgetChannelService._internal();
  factory WidgetChannelService() => _instance;

  WidgetChannelService._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Initialize the service - call from main.dart
  void init({
    required Function(int widgetId, String doorIdentifier, String doorName)
        onOpenDoor,
    required Function(int widgetId, String? widgetType) onConfigureDoor,
  }) {
    this.onOpenDoor = onOpenDoor;
    this.onConfigureDoor = onConfigureDoor;
  }

  /// Handle incoming calls from Android
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'openDoor':
        final args = Map<String, dynamic>.from(call.arguments);
        final widgetId = args['widgetId'] as int;
        final doorIdentifier = args['doorIdentifier'] as String;
        final doorName = args['doorName'] as String;

        if (onOpenDoor != null) {
          // Return bool indicating success
          try {
            onOpenDoor!(widgetId, doorIdentifier, doorName);
            return true;
          } catch (e) {
            return false;
          }
        }
        return false;

      case 'configureDoor':
        final args = Map<String, dynamic>.from(call.arguments);
        final widgetId = args['widgetId'] as int;
        final widgetType = args['widgetType'] as String?;

        onConfigureDoor?.call(widgetId, widgetType);
        return null;

      case 'getWidgetState':
        final widgetId = call.arguments as int;
        // Return stored door info if available
        // This will be implemented when we have a local widget store
        return null;

      default:
        throw PlatformException(
          code: 'NOT_IMPLEMENTED',
          message: 'Method ${call.method} not implemented',
        );
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
      print('Failed to update widget: ${e.message}');
    }
  }

  /// Notify Android that door was not found
  Future<void> showNotFound(int widgetId) async {
    try {
      await _channel.invokeMethod('showNotFound', {
        'widgetId': widgetId,
      });
    } on PlatformException catch (e) {
      print('Failed to show not found: ${e.message}');
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
      print('Failed to save door config: ${e.message}');
    }
  }
}
