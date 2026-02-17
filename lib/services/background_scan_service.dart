import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'settings_service.dart';
import 'favorites_service.dart';
import 'notification_service.dart';
import '../ble/ble_manager.dart';
import '../ui/scanner/managers/device_filter.dart';

/// Arka plan BLE tarama servisi
/// Android Foreground Service olarak calisir, uygulama arka plandayken bile tarar
class BackgroundScanService {
  static bool _running = false;

  static bool get isRunning => _running;

  /// Foreground task'i yapilandir
  static void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'background_scan',
        channelName: 'Arka Plan Tarama',
        channelDescription: 'BLE kapi taramasi arka planda devam ediyor',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Arka plan taramayi baslat
  static Future<bool> start() async {
    final enabled = await SettingsService.isBackgroundScanEnabled();
    if (!enabled) return false;

    if (_running) {
      debugPrint('BackgroundScan: Zaten calisiyor');
      return true;
    }

    initForegroundTask();

    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'ENKA GS',
      notificationText: 'Kapi taraniyor...',
      callback: backgroundScanCallback,
    );

    _running = result == ServiceRequestResult.success;
    debugPrint('BackgroundScan: Basladi=$_running');
    return _running;
  }

  /// Arka plan taramayi durdur
  static Future<void> stop() async {
    if (!_running) return;
    await FlutterForegroundTask.stopService();
    _running = false;
    debugPrint('BackgroundScan: Durduruldu');
  }
}

/// Foreground task callback - isolate icinde calisir
@pragma('vm:entry-point')
void backgroundScanCallback() {
  FlutterForegroundTask.setTaskHandler(BackgroundScanTaskHandler());
}

/// Background task handler
class BackgroundScanTaskHandler extends TaskHandler {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanSub;
  final Map<String, DateTime> _notifiedDevices = {};

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('BackgroundScanTask: Baslatildi');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _doScan();
  }

  Future<void> _doScan() async {
    debugPrint('BackgroundScanTask: Tarama basladi');
    await _scanSub?.cancel();

    final favoriteIds = await FavoritesService.getFavoriteIds();
    if (favoriteIds.isEmpty) {
      debugPrint('BackgroundScanTask: Favori kapi yok, tarama atlanıyor');
      return;
    }

    _scanSub = _ble.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      // Politeknik cihaz filtresi
      if (device.manufacturerData.length >= 6 &&
          device.manufacturerData[0] == 0x50 &&
          device.manufacturerData[1] == 0x54 &&
          device.manufacturerData[4] == 0x50 &&
          device.manufacturerData[5] == 0x54) {

        if (favoriteIds.contains(device.id)) {
          _onFavoriteDoorFound(device);
        }
      }
    });

    // 5 saniye tara, sonra durdur
    await Future.delayed(const Duration(seconds: 5));
    await _scanSub?.cancel();
    _scanSub = null;
    debugPrint('BackgroundScanTask: Tarama bitti');
  }

  void _onFavoriteDoorFound(DiscoveredDevice device) {
    // Ayni cihaz icin 60sn icerisinde tekrar bildirim gonderme
    final lastNotified = _notifiedDevices[device.id];
    if (lastNotified != null &&
        DateTime.now().difference(lastNotified).inSeconds < 60) {
      return;
    }
    _notifiedDevices[device.id] = DateTime.now();

    String doorName = 'Kapi';
    if (device.manufacturerData.length > 14) {
      try {
        doorName = String.fromCharCodes(device.manufacturerData.sublist(14));
      } catch (_) {}
    }

    debugPrint('BackgroundScanTask: Favori kapi bulundu - $doorName (${device.id}) RSSI: ${device.rssi}');

    NotificationService.showDoorNearbyNotification(
      doorId: device.id,
      doorName: doorName,
      rssi: device.rssi,
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('BackgroundScanTask: Yok edildi');
    await _scanSub?.cancel();
  }
}
