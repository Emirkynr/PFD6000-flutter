import '../../../ble/ble_service.dart';

/// BLE bağlantı yöneticisi
/// Cihazlara bağlanma/bağlantı kesme işlemleri
/// Bağlantı durumu takibi
class ConnectionManager {
  final BleService bleService;
  final Map<String, bool> deviceConnections;
  
  /// Bağlantı devam ediyor mu?
  bool isConnecting = false;
  
  /// Şu anda bağlı olan cihaz ID'si
  String? currentDeviceId;

  ConnectionManager({
    required this.bleService,
    required this.deviceConnections,
  });

  /// Cihaza bağlan
  /// Zaten bağlıysa true döner, aksi halde bağlantı kurar
  /// @param deviceId Cihaz ID'si
  /// @return true ise bağlantı başarılı
  Future<bool> connectToDevice(String deviceId) async {
    if (deviceConnections[deviceId] == true && bleService.isConnected) {
      return true;
    }

    if (isConnecting) {
      return false;
    }

    isConnecting = true;
    currentDeviceId = deviceId;

    try {
      if (bleService.isConnected) {
        await bleService.disconnect();
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final success = await bleService.connectToDevice(deviceId);
      if (success) {
        await bleService.discoverServices(deviceId);
        deviceConnections[deviceId] = true;
        return true;
      }
      return false;
    } catch (e) {
      print('Bağlantı hatası: $e');
      return false;
    } finally {
      isConnecting = false;
    }
  }

  /// Cihaz bağlantısını kes
  /// BLE bağlantısını sonlandırır ve durumu günceller
  /// @param deviceId Cihaz ID'si
  Future<void> disconnectFromDevice(String deviceId) async {
    await bleService.disconnect();
    deviceConnections[deviceId] = false;
    currentDeviceId = null;
  }

  /// Cihaz bağlantı durumunu kontrol et
  /// @param deviceId Cihaz ID'si
  /// @return true ise cihaz bağlı
  bool isDeviceConnected(String deviceId) {
    return deviceConnections[deviceId] ?? false;
  }
}
