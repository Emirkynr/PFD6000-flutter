import 'package:shared_preferences/shared_preferences.dart';

/// Kart numarası yönetimi
/// SharedPreferences ile kart numarasını kaydetme/okuma
/// Byte ↔ String dönüşüm fonksiyonları
class CardManager {
  /// Kart numarasını SharedPreferences'a kaydet
  /// @param cardBytes Kart numarası byte dizisi (16 veya 32 byte)
  static Future<void> saveCardToConfig(List<int> cardBytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cardString = cardBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
      await prefs.setString('configured_card_number', cardString);
    } catch (e) {
      print('Kart kaydetme hatası: $e');
    }
  }

  /// Kayıtlı kart numarasını al
  /// @return Kart numarası byte dizisi, kayıtlı değilse boş liste
  static Future<List<int>> getConfiguredCardNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cardString = prefs.getString('configured_card_number');
      if (cardString != null && cardString.isNotEmpty) {
        return _hexStringToBytes(cardString);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// HEX string'i byte dizisine çevir
  /// @param hexString "A1B2C3" formatında HEX string
  /// @return Byte dizisi
  static List<int> _hexStringToBytes(String hexString) {
    try {
      final bytes = <int>[];
      for (int i = 0; i < hexString.length; i += 2) {
        final hexByte = hexString.substring(i, i + 2);
        bytes.add(int.parse(hexByte, radix: 16));
      }
      return bytes;
    } catch (e) {
      return [];
    }
  }

  /// Byte dizisini HEX string'e çevir
  /// @param bytes Byte dizisi
  /// @return "a1b2c3" formatında HEX string (küçük harf)
  static String bytesToHexString(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  /// Byte dizisini ASCII string'e çevir
  /// @param bytes Byte dizisi
  /// @return ASCII string, hata durumunda boş string
  static String bytesToString(List<int> bytes) {
    try {
      return String.fromCharCodes(bytes);
    } catch (e) {
      return '';
    }
  }
}
