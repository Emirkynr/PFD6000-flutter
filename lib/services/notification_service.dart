import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'settings_service.dart';

/// Bildirim yonetim servisi
/// Kapi yakininda bildirim gosterme ve aksiyon butonlari
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // Bildirim kanallari
  static const _doorNearbyChannel = AndroidNotificationChannel(
    'door_nearby',
    'Kapi Bildirimleri',
    description: 'Kapi yakininda bildirim gosterir',
    importance: Importance.high,
  );

  static const _autoOpenResultChannel = AndroidNotificationChannel(
    'auto_open_result',
    'Otomatik Acma Sonuclari',
    description: 'Otomatik kapi acma sonuclarini gosterir',
    importance: Importance.low,
  );

  static const _backgroundScanChannel = AndroidNotificationChannel(
    'background_scan',
    'Arka Plan Tarama',
    description: 'Arka plan BLE tarama durumu',
    importance: Importance.low,
  );

  // Callback - bildirim aksiyonu tiklandiginda
  static Function(String doorId, String action)? onNotificationAction;

  /// Servisi baslat
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Android bildirim kanallarini olustur
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_doorNearbyChannel);
      await androidPlugin.createNotificationChannel(_autoOpenResultChannel);
      await androidPlugin.createNotificationChannel(_backgroundScanChannel);
    }

    _initialized = true;
    debugPrint('NotificationService: Initialized');
  }

  /// Bildirim aksiyonu callback
  static void _onNotificationResponse(NotificationResponse response) {
    debugPrint('NotificationService: Action=${response.actionId} payload=${response.payload}');
    final payload = response.payload;
    if (payload == null) return;

    // payload formati: "doorId|action"
    final parts = payload.split('|');
    if (parts.length >= 2) {
      onNotificationAction?.call(parts[0], parts[1]);
    } else if (response.actionId != null && response.actionId!.isNotEmpty) {
      onNotificationAction?.call(payload, response.actionId!);
    } else {
      // Bildirime tiklandiginda varsayilan giris
      onNotificationAction?.call(payload, 'entry');
    }
  }

  /// Kapi yakininda bildirim goster
  static Future<void> showDoorNearbyNotification({
    required String doorId,
    required String doorName,
    required int rssi,
  }) async {
    final enabled = await SettingsService.isNotificationEnabled();
    if (!enabled) return;

    final sound = await SettingsService.isNotificationSoundEnabled();
    final vibrate = await SettingsService.isNotificationVibrateEnabled();

    final androidDetails = AndroidNotificationDetails(
      _doorNearbyChannel.id,
      _doorNearbyChannel.name,
      channelDescription: _doorNearbyChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: sound,
      enableVibration: vibrate,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'entry',
          'Giris Yap',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'exit',
          'Cikis Yap',
          showsUserInterface: true,
        ),
      ],
    );

    await _plugin.show(
      doorId.hashCode,
      '$doorName yakininda',
      'Giris icin dokun',
      NotificationDetails(android: androidDetails),
      payload: '$doorId|entry',
    );

    debugPrint('NotificationService: Showed door nearby notification for $doorName');
  }

  /// Otomatik acma sonuc bildirimi
  static Future<void> showAutoOpenResult({
    required String doorName,
    required bool success,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _autoOpenResultChannel.id,
      _autoOpenResultChannel.name,
      channelDescription: _autoOpenResultChannel.description,
      importance: Importance.low,
      priority: Priority.low,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      success ? 'Kapi acildi' : 'Kapi acilamadi',
      doorName,
      NotificationDetails(android: androidDetails),
    );
  }

  /// Arka plan tarama kalici bildirimi ID'si
  static const int backgroundNotificationId = 888;

  /// Bildirimi kaldir
  static Future<void> cancelDoorNotification(String doorId) async {
    await _plugin.cancel(doorId.hashCode);
  }

  /// Tum bildirimleri kaldir
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
