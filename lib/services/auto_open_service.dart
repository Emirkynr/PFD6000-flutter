import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'settings_service.dart';
import 'favorites_service.dart';

/// Yaklasim bazli otomatik kapi acma servisi
/// Favori kapilarin RSSI degerini izler, esik gecildiginde tetikler
class AutoOpenService {
  // Cooldown: deviceId -> son tetikleme zamani
  final Map<String, DateTime> _cooldowns = {};

  // Surekli tetiklemeyi engellemek icin islem kilidi
  bool _processing = false;

  /// Cihaz listesini kontrol et, esik gecen favori kapi varsa tetikle
  /// Dondurulen deger: tetiklenmesi gereken deviceId veya null
  Future<String?> checkDevices(List<DiscoveredDevice> devices) async {
    if (_processing) return null;

    final enabled = await SettingsService.isAutoOpenEnabled();
    if (!enabled) return null;

    final favoriteIds = await FavoritesService.getFavoriteIds();
    if (favoriteIds.isEmpty) return null;

    final rssiThreshold = await SettingsService.getAutoOpenRssiThreshold();
    final cooldownSeconds = await SettingsService.getAutoOpenCooldownSeconds();

    for (final device in devices) {
      if (!favoriteIds.contains(device.id)) continue;
      if (device.rssi < rssiThreshold) continue;

      // Cooldown kontrolu
      if (_isInCooldown(device.id, cooldownSeconds)) continue;

      // Tetikle
      debugPrint('AutoOpen: Kapi tespit edildi - ${device.name} (${device.id}) RSSI: ${device.rssi} >= $rssiThreshold');
      _processing = true;
      _cooldowns[device.id] = DateTime.now();
      return device.id;
    }

    return null;
  }

  /// Islem tamamlandi, kilidi kaldir
  void completeProcessing() {
    _processing = false;
  }

  /// Cooldown kontrolu
  bool _isInCooldown(String deviceId, int cooldownSeconds) {
    final lastTrigger = _cooldowns[deviceId];
    if (lastTrigger == null) return false;
    return DateTime.now().difference(lastTrigger).inSeconds < cooldownSeconds;
  }

  /// Biyometrik gerekli mi
  Future<bool> isBiometricRequired() async {
    return SettingsService.isAutoOpenBiometricRequired();
  }

  /// Sadece giris mi
  Future<bool> isEntryOnly() async {
    return SettingsService.isAutoOpenEntryOnly();
  }

  void dispose() {
    _cooldowns.clear();
  }
}
