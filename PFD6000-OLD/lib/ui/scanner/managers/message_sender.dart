import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../../../ble/ble_service.dart';
import 'card_manager.dart';
import 'device_filter.dart';
import '../../../globals.dart';

/// BLE mesaj gönderme yöneticisi
/// Giriş/çıkış/konfigürasyon mesajlarını hazırlar ve gönderir
/// Raw data'dan şifre çıkarıp mesaja ekler
class MessageSender {
  final BleService bleService;

  /// Son çıkarılan şifre bilgileri
  /// Her mesaj gönderiminde raw data'dan güncellenir
  List<int> _lastPasswordBytes = [];
  int _lastPasswordInt = 0;

  MessageSender({required this.bleService});

  /// Şifre getter'ları - UI'da gösterilmez, sadakece mesaja eklenir
  List<int> get lastPasswordBytes => _lastPasswordBytes;
  int get lastPasswordInt => _lastPasswordInt;

  /// Giriş komutu - 16 byte sabit komut
  static const  List<int> entryCommand = [
    0x69, 0x7D, 0x63, 0x30, 0xC1, 0xA3, 0xF4, 0x79,
    0xDB, 0x5B, 0x3E, 0xF0, 0x52, 0xDF, 0x7D, 0xC6
  ];

  /// Konfigürasyon komutu - 32 byte sabit komut
  /// ESP32'ye kart okutma modunu aktif eder
  static const List<int> configCommand = [
//    0x69, 0x7D, 0x63, 0x30, 0xC1, 0xA3, 0xF4, 0x79,
//    0xDB, 0x5B, 0x3E, 0xF0, 0x52, 0xDF, 0x7D, 0xC6,
    0xAE, 0xE8, 0x47, 0x3C, 0xEB, 0xA2, 0xA5, 0x6C,
    0xD6, 0xF8, 0xB6, 0x28, 0x05, 0x68, 0x32, 0x38
  ];

//  Future<List<int>> check_newMD5() async
  List<int> check_newMD5()
  {
    if ( newMD5.isNotEmpty )
    {
     return newMD5;
    }
    return entryCommand;
  }
  /// Giriş mesajı gönder
  /// Format: [komut 16] + [kart 16/32] + [flag 0x00] + [şifre 8] = 41/57 byte
  /// @param cardBytes Kayıtlı kart numarası
  /// @param device BLE cihazı (şifre çıkarmak için)
  /// @return true ise başarılı
  Future<bool> sendEntryMessage(List<int> cardBytes, DiscoveredDevice device) async {
    try {
      // Şifreyi kaydet
      _lastPasswordBytes = DeviceFilter.extractPassword(device);
      _lastPasswordInt = DeviceFilter.extractPasswordAsInt(device);
      List<int> startBytes=check_newMD5();
      final binaryMessage = [...startBytes, ...cardBytes, 0x00,..._lastPasswordBytes];
      await bleService.sendBinaryMessage(binaryMessage);
      return true;
    } catch (e) {
      print('Giriş mesajı hatası: $e');
      return false;
    }
  }

  /// Çıkış mesajı gönder
  /// Format: [komut 16] + [kart 16/32] + [flag 0x01] + [şifre 8] = 41/57 byte
  /// @param cardBytes Kayıtlı kart numarası
  /// @param device BLE cihazı (şifre çıkarmak için)
  /// @return true ise başarılı
  Future<bool> sendExitMessage(List<int> cardBytes, DiscoveredDevice device) async {
    try {
      // Şifreyi kaydet
      _lastPasswordBytes = DeviceFilter.extractPassword(device);
      _lastPasswordInt = DeviceFilter.extractPasswordAsInt(device);
      List<int> startBytes=check_newMD5();

      final binaryMessage = [...startBytes, ...cardBytes, 0x01,..._lastPasswordBytes];
      await bleService.sendBinaryMessage(binaryMessage);
      return true;
    } catch (e) {
      print('Çıkış mesajı hatası: $e');
      return false;
    }
  }

  /// Konfigürasyon mesajı gönder
  /// ESP32'ye 32 byte'lık config command gönderir
  /// @return true ise başarılı
  Future<bool> sendConfigMessage() async {
    try {
      List<int> startBytes=check_newMD5();
      final binaryMessage = [...startBytes, ...configCommand];
      await bleService.sendBinaryMessage(binaryMessage);//configCommand);
      return true;
    } catch (e) {
      print('Konfigürasyon mesajı hatası: $e');
      return false;
    }
  }

  /// Giriş mesajı bilgilerini al (UI için)
  /// Komut, kart, toplam byte bilgilerini içerir
  static Map<String, dynamic> getEntryMessageInfo(List<int> cardBytes) {
    final commandHex = entryCommand.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    final cardString = CardManager.bytesToString(cardBytes);
    final totalBytes = entryCommand.length + cardBytes.length + 1;

    return {
      'commandHex': commandHex,
      'cardString': cardString,
      'cardLength': cardBytes.length,
      'totalBytes': totalBytes,
    };
  }

  /// Çıkış mesajı bilgilerini al (UI için)
  /// Kart, toplam byte bilgilerini içerir
  static Map<String, dynamic> getExitMessageInfo(List<int> cardBytes) {
    final cardHex = CardManager.bytesToHexString(cardBytes);
    final cardString = CardManager.bytesToString(cardBytes);
    final totalBytes = cardBytes.length + 1;

    return {
      'cardHex': cardHex,
      'cardString': cardString,
      'totalBytes': totalBytes,
    };
  }
}
