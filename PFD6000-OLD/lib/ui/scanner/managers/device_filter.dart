import 'dart:typed_data';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

/// BLE cihaz filtreleme ve raw data parsing
/// Raw data formatı: [0x50 0x54] [2 byte] [2 byte] [0x50 0x54] [8 byte şifre] [device name...]
/// Index 0-1: Manufacturer ID (0x50 0x54)
/// Index 6-13: 8 byte random şifre
/// Index 14+: Cihaz ismi (değişken uzunluk)
class DeviceFilter {
  /// Raw data'da 0x50 0x54 prefix kontrolü
  /// Manufacturer data farklı formatlarda olabilir: Uint8List, Map<int, List<int>>, Map
  /// @return true ise cihaz Poli BLE cihazıdır
  static bool hasRawData5054(DiscoveredDevice device) {
    try {
      final dynamic manufacturerData = device.manufacturerData;
      
      if (manufacturerData is Uint8List) {
        if (manufacturerData.length >= 2 &&
            manufacturerData[0] == 0x50 &&
            manufacturerData[1] == 0x54) {
          return true;
        }
      } else if (manufacturerData is Map<int, List<int>>) {
        for (final entry in manufacturerData.entries) {
          final data = entry.value;
          if (data.length >= 2 && data[0] == 0x50 && data[1] == 0x54) {
            return true;
          }
        }
      } else if (manufacturerData is Map) {
        for (final entry in manufacturerData.entries) {
          final value = entry.value;
          if (value is List && value.length >= 2) {
            try {
              final data = List<int>.from(value);
              if (data[0] == 0x50 && data[1] == 0x54) {
                return true;
              }
            } catch (_) {}
          }
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Raw data'dan cihaz ismini çıkar
  /// Index 14'ten sonuna kadar olan byte'lar cihaz ismidir
  /// @return Cihaz ismi string, bulunamazsa "Unknown"
  static String extractDeviceName(DiscoveredDevice device) {
    try {
      final dynamic manufacturerData = device.manufacturerData;
      List<int>? data;
      
      if (manufacturerData is Uint8List) {
        data = manufacturerData;
      } else if (manufacturerData is Map<int, List<int>>) {
        data = manufacturerData.values.firstOrNull;
      } else if (manufacturerData is Map) {
        for (final entry in manufacturerData.entries) {
          final value = entry.value;
          if (value is List) {
            data = List<int>.from(value);
            break;
          }
        }
      }
      
      if (data != null && data.length > 14) {
        // Index 14'ten sonuna kadar cihaz ismi
        final nameBytes = data.sublist(14);
        return String.fromCharCodes(nameBytes);
      }
      
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Raw data'dan 8 byte şifreyi çıkar
  /// Index 6-13 arası 8 byte random şifre içerir
  /// @return 8 byte'lık liste, bulunamazsa boş liste
  static List<int> extractPassword(DiscoveredDevice device) {
    try {
      final dynamic manufacturerData = device.manufacturerData;
      List<int>? data;
      
      if (manufacturerData is Uint8List) {
        data = manufacturerData;
      } else if (manufacturerData is Map<int, List<int>>) {
        data = manufacturerData.values.firstOrNull;
      } else if (manufacturerData is Map) {
        for (final entry in manufacturerData.entries) {
          final value = entry.value;
          if (value is List) {
            data = List<int>.from(value);
            break;
          }
        }
      }
      
      if (data != null && data.length >= 14) {
        // Index 6-13: 8 byte şifre
        return data.sublist(6, 14);
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Şifreyi integer'a çevir (big-endian)
  /// 8 byte'ı tek bir int değerine dönüştürür
  /// @return Şifre int değeri, hata durumunda 0
  static int extractPasswordAsInt(DiscoveredDevice device) {
    try {
      final passwordBytes = extractPassword(device);
      if (passwordBytes.isEmpty) return 0;
      
      // 8 byte'ı int'e çevir (big-endian)
      int result = 0;
      for (var byte in passwordBytes) {
        result = (result << 8) | byte;
      }
      return result;
    } catch (e) {
      return 0;
    }
  }
}
