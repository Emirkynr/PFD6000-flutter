import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama ayarlarini yoneten servis
/// Tum ayarlar SharedPreferences'ta saklanir, cache ile hizlandirilir
class SettingsService {
  // SharedPreferences anahtarlari
  static const _autoOpenEnabled = 'auto_open_enabled';
  static const _autoOpenRssiThreshold = 'auto_open_rssi_threshold';
  static const _autoOpenCooldownSeconds = 'auto_open_cooldown_seconds';
  static const _autoOpenRequireBiometric = 'auto_open_require_biometric';
  static const _autoOpenEntryOnly = 'auto_open_entry_only';
  static const _backgroundScanEnabled = 'background_scan_enabled';
  static const _notificationEnabled = 'notification_enabled';
  static const _notificationSound = 'notification_sound';
  static const _notificationVibrate = 'notification_vibrate';
  static const _quickMode = 'quick_mode';

  // Cache
  static bool? _cachedAutoOpen;
  static bool? _cachedQuickMode;
  static int? _cachedRssiThreshold;
  static int? _cachedCooldown;
  static bool? _cachedBiometric;
  static bool? _cachedEntryOnly;
  static bool? _cachedBackgroundScan;
  static bool? _cachedNotification;
  static bool? _cachedNotifSound;
  static bool? _cachedNotifVibrate;

  // --- Otomatik Acma ---

  static Future<bool> isAutoOpenEnabled() async {
    if (_cachedAutoOpen != null) return _cachedAutoOpen!;
    final prefs = await SharedPreferences.getInstance();
    _cachedAutoOpen = prefs.getBool(_autoOpenEnabled) ?? false;
    return _cachedAutoOpen!;
  }

  static Future<void> setAutoOpenEnabled(bool value) async {
    _cachedAutoOpen = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoOpenEnabled, value);
  }

  static Future<int> getAutoOpenRssiThreshold() async {
    if (_cachedRssiThreshold != null) return _cachedRssiThreshold!;
    final prefs = await SharedPreferences.getInstance();
    _cachedRssiThreshold = prefs.getInt(_autoOpenRssiThreshold) ?? -55;
    return _cachedRssiThreshold!;
  }

  static Future<void> setAutoOpenRssiThreshold(int value) async {
    _cachedRssiThreshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoOpenRssiThreshold, value);
  }

  static Future<int> getAutoOpenCooldownSeconds() async {
    if (_cachedCooldown != null) return _cachedCooldown!;
    final prefs = await SharedPreferences.getInstance();
    _cachedCooldown = prefs.getInt(_autoOpenCooldownSeconds) ?? 30;
    return _cachedCooldown!;
  }

  static Future<void> setAutoOpenCooldownSeconds(int value) async {
    _cachedCooldown = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoOpenCooldownSeconds, value);
  }

  static Future<bool> isAutoOpenBiometricRequired() async {
    if (_cachedBiometric != null) return _cachedBiometric!;
    final prefs = await SharedPreferences.getInstance();
    _cachedBiometric = prefs.getBool(_autoOpenRequireBiometric) ?? false;
    return _cachedBiometric!;
  }

  static Future<void> setAutoOpenBiometricRequired(bool value) async {
    _cachedBiometric = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoOpenRequireBiometric, value);
  }

  static Future<bool> isAutoOpenEntryOnly() async {
    if (_cachedEntryOnly != null) return _cachedEntryOnly!;
    final prefs = await SharedPreferences.getInstance();
    _cachedEntryOnly = prefs.getBool(_autoOpenEntryOnly) ?? true;
    return _cachedEntryOnly!;
  }

  static Future<void> setAutoOpenEntryOnly(bool value) async {
    _cachedEntryOnly = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoOpenEntryOnly, value);
  }

  // --- Arka Plan Tarama ---

  static Future<bool> isBackgroundScanEnabled() async {
    if (_cachedBackgroundScan != null) return _cachedBackgroundScan!;
    final prefs = await SharedPreferences.getInstance();
    _cachedBackgroundScan = prefs.getBool(_backgroundScanEnabled) ?? false;
    return _cachedBackgroundScan!;
  }

  static Future<void> setBackgroundScanEnabled(bool value) async {
    _cachedBackgroundScan = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backgroundScanEnabled, value);
  }

  // --- Bildirimler ---

  static Future<bool> isNotificationEnabled() async {
    if (_cachedNotification != null) return _cachedNotification!;
    final prefs = await SharedPreferences.getInstance();
    _cachedNotification = prefs.getBool(_notificationEnabled) ?? false;
    return _cachedNotification!;
  }

  static Future<void> setNotificationEnabled(bool value) async {
    _cachedNotification = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationEnabled, value);
  }

  static Future<bool> isNotificationSoundEnabled() async {
    if (_cachedNotifSound != null) return _cachedNotifSound!;
    final prefs = await SharedPreferences.getInstance();
    _cachedNotifSound = prefs.getBool(_notificationSound) ?? true;
    return _cachedNotifSound!;
  }

  static Future<void> setNotificationSoundEnabled(bool value) async {
    _cachedNotifSound = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationSound, value);
  }

  static Future<bool> isNotificationVibrateEnabled() async {
    if (_cachedNotifVibrate != null) return _cachedNotifVibrate!;
    final prefs = await SharedPreferences.getInstance();
    _cachedNotifVibrate = prefs.getBool(_notificationVibrate) ?? true;
    return _cachedNotifVibrate!;
  }

  static Future<void> setNotificationVibrateEnabled(bool value) async {
    _cachedNotifVibrate = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationVibrate, value);
  }

  // --- Hızlı Mod ---

  static Future<bool> isQuickModeEnabled() async {
    if (_cachedQuickMode != null) return _cachedQuickMode!;
    final prefs = await SharedPreferences.getInstance();
    _cachedQuickMode = prefs.getBool(_quickMode) ?? false;
    return _cachedQuickMode!;
  }

  static Future<void> setQuickModeEnabled(bool value) async {
    _cachedQuickMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_quickMode, value);
  }

  /// Tum ayarlari onbellege al
  static Future<void> preload() async {
    await isAutoOpenEnabled();
    await getAutoOpenRssiThreshold();
    await getAutoOpenCooldownSeconds();
    await isAutoOpenBiometricRequired();
    await isAutoOpenEntryOnly();
    await isBackgroundScanEnabled();
    await isNotificationEnabled();
    await isNotificationSoundEnabled();
    await isNotificationVibrateEnabled();
    await isQuickModeEnabled();
  }
}
