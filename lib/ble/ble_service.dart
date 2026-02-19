import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class BleService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  // Stream controllers
  final _connectionController = StreamController<DeviceConnectionState>.broadcast();
  final _messageController = StreamController<String>.broadcast();
  final _numberController = StreamController<List<int>>.broadcast(); // Byte array stream
  final _dataController = StreamController<String>.broadcast();

  // Connection state
  DeviceConnectionState _connectionState = DeviceConnectionState.disconnected;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  QualifiedCharacteristic? _writeCharacteristic;
  QualifiedCharacteristic? _readCharacteristic;
  
  // Auto refresh timer
  Timer? _autoRefreshTimer;
  bool _isDemoMode = false;

  BleService() {
    _checkIfSimulator();
  }

  Future<void> _checkIfSimulator() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      if (!iosInfo.isPhysicalDevice) {
        _isDemoMode = true;
        print('BLE Service: iOS Simulator detected - Demo Mode ENABLED');
      }
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      if (!androidInfo.isPhysicalDevice) {
        _isDemoMode = true;
        print('BLE Service: Android Emulator detected - Demo Mode ENABLED');
      }
    }
  }

  Future<bool> connectToDevice(String deviceId) async {
    if (_isDemoMode) {
      print('BLE Service: Demo connection initiated...');
      await Future.delayed(const Duration(seconds: 1));
      _connectionState = DeviceConnectionState.connected;
      if (!_connectionController.isClosed) {
        _connectionController.add(_connectionState);
      }
      print('BLE Service: Demo Connected!');
      return true;
    }

    Future<bool> attemptConnect({required Duration timeout}) async {
      // Önce varsa önceki bağlantıyı iptal et
      await _connectionSubscription?.cancel();

      final completer = Completer<bool>();
      _connectionSubscription = _ble.connectToDevice(id: deviceId).listen(
        (update) {
          _connectionState = update.connectionState;
          if (!_connectionController.isClosed) {
            _connectionController.add(_connectionState);
          }
          print('Bağlantı durumu: $_connectionState');
          // Event-driven: bağlantı kurulunca hemen dön
          if (update.connectionState == DeviceConnectionState.connected && !completer.isCompleted) {
            completer.complete(true);
          }
        },
        onError: (error) {
          _connectionState = DeviceConnectionState.disconnected;
          if (!_connectionController.isClosed) {
            _connectionController.add(_connectionState);
          }
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      );

      // Timeout ile bekle - bağlantı kurulunca hemen döner
      return await completer.future.timeout(
        timeout,
        onTimeout: () => _connectionState == DeviceConnectionState.connected,
      );
    }

    // İlk deneme
    bool connected = await attemptConnect(timeout: const Duration(seconds: 3));
    if (connected) return true;

    // Bağlantıyı kes ve tekrar dene
    await disconnect();
    await Future.delayed(const Duration(milliseconds: 300));

    // İkinci deneme
    connected = await attemptConnect(timeout: const Duration(seconds: 3));
    return connected;
  }

  Future<void> discoverServices(String deviceId) async {
    if (_isDemoMode) {
      print('BLE Service: Demo Services Discovered');
      
      // Mock Characteristics
      _writeCharacteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse("0000180A-0000-1000-8000-00805F9B34FB"), 
        characteristicId: Uuid.parse("00002A29-0000-1000-8000-00805F9B34FB"), 
        deviceId: deviceId
      );
      _readCharacteristic = _writeCharacteristic;

      await startESPNotificationListening();
      _startAutoRefresh();
      return;
    }

    try {
      print('Servisler keşfediliyor...');
      await _ble.discoverAllServices(deviceId);
      final services = await _ble.getDiscoveredServices(deviceId);
      
      for (var service in services) {
        print('Servis bulundu: ${service.id}');
        for (var characteristic in service.characteristics) {
          print('Characteristic bulundu: ${characteristic.id}');
          
          // Write characteristic bul (WRITE property kontrolü)
          if (characteristic.id.toString().contains('2B29') || // Custom write characteristic
              characteristic.id.toString().contains('4321') || // Custom service characteristic
              characteristic.id.toString().toLowerCase().contains('write')) {
            _writeCharacteristic = QualifiedCharacteristic(
              serviceId: service.id,
              characteristicId: characteristic.id,
              deviceId: deviceId,
            );
            print('Write characteristic bulundu: ${characteristic.id}');
          }
          
          // Read characteristic bul (READ property kontrolü)
          if (characteristic.id.toString().contains('2B3A') || // Custom read characteristic
              characteristic.id.toString().contains('2B29') || // Custom read/write characteristic
              characteristic.id.toString().contains('4321') || // Custom service characteristic
              characteristic.id.toString().toLowerCase().contains('read') ||
              characteristic.id.toString().toLowerCase().contains('notify')) {
            _readCharacteristic = QualifiedCharacteristic(
              serviceId: service.id,
              characteristicId: characteristic.id,
              deviceId: deviceId,
            );
            print('Read characteristic bulundu: ${characteristic.id}');
          }
        }
      }
      
      if (_writeCharacteristic == null) {
        print('Write characteristic bulunamadı!');
        // Alternatif: İlk bulunan characteristic'i kullan
        for (var service in services) {
          if (service.characteristics.isNotEmpty) {
            _writeCharacteristic = QualifiedCharacteristic(
              serviceId: service.id,
              characteristicId: service.characteristics.first.id,
              deviceId: deviceId,
            );
            print('Alternatif Write characteristic: ${service.characteristics.first.id}');
            break;
          }
        }
      }
      if (_readCharacteristic == null) {
        print('Read characteristic bulunamadı!');
        // Alternatif: İkinci bulunan characteristic'i kullan
        for (var service in services) {
          if (service.characteristics.length > 1) {
            _readCharacteristic = QualifiedCharacteristic(
              serviceId: service.id,
              characteristicId: service.characteristics[1].id,
              deviceId: deviceId,
            );
            print('Alternatif Read characteristic: ${service.characteristics[1].id}');
            break;
          } else if (service.characteristics.isNotEmpty) {
            _readCharacteristic = QualifiedCharacteristic(
              serviceId: service.id,
              characteristicId: service.characteristics.first.id,
              deviceId: deviceId,
            );
            print('Alternatif Read characteristic: ${service.characteristics.first.id}');
            break;
          }
        }
      }
      
      // Notification dinleme başlat
      if (_readCharacteristic != null) {
        await startESPNotificationListening();
        // 3 saniyede bir otomatik yenileme başlat
        _startAutoRefresh();
      }
    } catch (e) {
      print('Servis keşfi hatası: $e');
    }
  }

  Future<void> sendMessage(String message) async {
    if (_isDemoMode) {
      print('BLE Service: Demo Message Sent: $message');
      if (!_messageController.isClosed) {
        _messageController.add('Gönderilen: $message');
      }
      return;
    }

    if (_writeCharacteristic == null) {
      print('Write characteristic bulunamadı!');
      return;
    }

    try {
      final data = Uint8List.fromList(message.codeUnits);
      await _ble.writeCharacteristicWithResponse(_writeCharacteristic!, value: data);
      print('Mesaj gönderildi: $message');
      
      if (!_messageController.isClosed) {
        _messageController.add('Gönderilen: $message');
      }
    } catch (e) {
      print('Mesaj gönderme hatası: $e');
      if (!_messageController.isClosed) {
        _messageController.add('Gönderme Hatası: $e');
      }
    }
  }

  /// Binary mesaj gönder - Direkt byte array olarak gönder
  Future<void> sendBinaryMessage(List<int> binaryData) async {
    if (_isDemoMode) {
      print('BLE Service: Demo Binary Message Sent: ${binaryData.length} bytes');
       final data = Uint8List.fromList(binaryData);
      if (!_messageController.isClosed) {
        _messageController.add('Mesaj gönderildi: ${data.length} byte');
      }
      return;
    }

    if (_writeCharacteristic == null) {
      print('Write characteristic bulunamadı!');
      return;
    }

    try {
      print('=== MESAJ GÖNDERİLİYOR ===');
      
      // 1. Byte Array
      print('1. BYTE ARRAY (${binaryData.length} byte):');
      print('   ${binaryData.map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}').join(' ')}');
      
      // Direkt byte array'i gönder (HEX string'e ÇEVİRME!)
      final data = Uint8List.fromList(binaryData);
      
      await _ble.writeCharacteristicWithResponse(_writeCharacteristic!, value: data);
      print('✓ Mesaj başarıyla gönderildi!');
      print('========================\n');
      
      if (!_messageController.isClosed) {
        _messageController.add('Mesaj gönderildi: ${data.length} byte');
      }
    } catch (e) {
      print('✗ Mesaj gönderme hatası: $e');
      print('========================\n');
      if (!_messageController.isClosed) {
        _messageController.add('Gönderme Hatası: $e');
      }
    }
  }

  Future<void> readData() async {
    if (_isDemoMode) {
      final dataString = "Demo Data ${DateTime.now().second}";
      print('Okunan veri: $dataString');
      if (!_dataController.isClosed) {
        _dataController.add('Okunan: $dataString');
      }
      return;
    }

    if (_readCharacteristic == null) {
      print('Read characteristic bulunamadı!');
      return;
    }

    try {
      final data = await _ble.readCharacteristic(_readCharacteristic!);
      final dataString = String.fromCharCodes(data);
      print('Okunan veri: $dataString');
      
      if (!_dataController.isClosed) {
        _dataController.add('Okunan: $dataString');
      }
    } catch (e) {
      print('Veri okuma hatası: $e');
      if (!_dataController.isClosed) {
        _dataController.add('Okuma Hatası: $e');
      }
    }
  }

  // readNumberFromESP fonksiyonu kaldırıldı - artık notification dinleme kullanıyoruz

  Future<void> readManufacturerDataFromESP() async {
    try {
      print('ESP\'den manufacturer data okunuyor...');
      
      // BLE cihazından manufacturer data al
      final deviceId = _readCharacteristic?.deviceId ?? '';
      if (deviceId.isNotEmpty) {
        // Manufacturer data'yı oku
        final manufacturerData = await _ble.readCharacteristic(_readCharacteristic!);
        
        // Manufacturer data'yı string'e çevir
        final dataString = String.fromCharCodes(manufacturerData);
        print('ESP Manufacturer Data: $dataString');
        
        // Data stream'e gönder
        if (!_dataController.isClosed) {
          _dataController.add('ESP Manufacturer Data: $dataString');
        }
      }
    } catch (e) {
      print('ESP manufacturer data okuma hatası: $e');
      if (!_dataController.isClosed) {
        _dataController.add('ESP Manufacturer Data Hatası: $e');
      }
    }
  }

  // readManufacturerIdFromESP fonksiyonu kaldırıldı - artık sadece notification dinleme kullanıyoruz

  // startContinuousESPReading fonksiyonu kaldırıldı - artık sadece notification dinleme kullanıyoruz

  /// ESP'den Tx karakteristiği ile notification dinleme - tüm verileri göster
  Future<void> startESPNotificationListening() async {
    if (!isConnected || _readCharacteristic == null) {
      print('ESP notification: Bağlantı yok veya read characteristic bulunamadı');
      return;
    }

    try {
      print('ESP Tx karakteristiği notification dinleme başlatılıyor...');
      
      // READ işlemi yapmıyoruz - sadece notification dinliyoruz
      print('ESP notification dinleme başlatıldı - READ işlemi yapılmıyor');
      
      if (_isDemoMode) {
         print('ESP Demo Notification dinleme başlatıldı');
         return;
      }
      
      // Debug: ESP cihazının veri gönderip göndermediğini kontrol et
      if (!_dataController.isClosed) {
        _dataController.add('ESP NOTIFY ve INDICATE Dinleme Başlatıldı');
        _dataController.add('ESP cihazı 3 saniyede bir değer fırlatmalı');
        _dataController.add('NOTIFY veya INDICATE ile veri gelecek');
        _dataController.add('Eğer değer gelmiyorsa ESP cihazı veri göndermiyor');
      }
      
      // Tx karakteristiği için hem NOTIFY hem de INDICATE dinle
      print('ESP characteristic özellikleri kontrol ediliyor...');
      
      // Önce NOTIFY dinle
      _ble.subscribeToCharacteristic(_readCharacteristic!).listen(
        (data) {
          print('\n=== ESP NOTIFICATION ALINDI ===');
          print('TOPLAM: ${data.length} byte');
          
          // 1. Byte Array
          print('1. BYTE ARRAY:');
          print('   ${data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}').join(' ')}');
          
          print('==============================\n');
          
          // Number stream'e gönder (Byte array format)
          if (!_numberController.isClosed) {
            _numberController.add(data);
          }
          
          // Data stream'e gönder
          if (!_dataController.isClosed) {
            _dataController.add('$data');
          }
        },
        onError: (error) {
          print('ESP Notification hatası: $error');
          if (!_dataController.isClosed) {
            _dataController.add('ESP Notification Hatası: $error');
          }
        },
      );
      
      // INDICATE için de dinle (ESP cihazı INDICATE kullanıyor olabilir)
      print('ESP INDICATE dinleme de başlatılıyor...');
      
      // Aynı characteristic'i tekrar dinle (INDICATE için)
      _ble.subscribeToCharacteristic(_readCharacteristic!).listen(
        (data) {
          print('\n=== ESP INDICATE ALINDI ===');
          print('TOPLAM: ${data.length} byte');
          
          // 1. Byte Array
          print('1. BYTE ARRAY:');
          print('   ${data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}').join(' ')}');
          
          print('===========================\n');
          
          // Number stream'e byte array gönder
          if (!_numberController.isClosed) {
            _numberController.add(data);
          }
          
          // Data stream'e tüm formatları gönder
          if (!_dataController.isClosed) {
            _dataController.add('=== ESP INDICATE (${data.length} Byte) ===');
            _dataController.add('========================');
          }
        },
        onError: (error) {
          print('ESP INDICATE hatası: $error');
          if (!_dataController.isClosed) {
            _dataController.add('ESP INDICATE Hatası: $error');
          }
        },
      );
      
      print('ESP hem NOTIFY hem INDICATE dinleme başlatıldı');
    } catch (e) {
      print('ESP notification başlatma hatası: $e');
      if (!_dataController.isClosed) {
        _dataController.add('ESP Notification Başlatma Hatası: $e');
      }
    }
  }

  /// Company ID değiştirme bilgisi
  Future<void> changeCompanyIdInfo() async {
    try {
      if (!_dataController.isClosed) {
        _dataController.add('=== Company ID Değiştirme Bilgisi ===');
        _dataController.add('ESP cihazında company ID değiştirmek için:');
        _dataController.add('1. ESP32/ESP8266 kodunda BLE_ADVERTISING ayarları');
        _dataController.add('2. esp_ble_gap_config_adv_data() fonksiyonu');
        _dataController.add('3. manufacturer_data parametresi');
        _dataController.add('4. İlk 2 byte company ID olarak ayarlanır');
        _dataController.add('5. Örnek: 0x1234 (kendi company ID\'niz)');
        _dataController.add('6. Bluetooth SIG\'den resmi company ID alabilirsiniz');
        _dataController.add('7. Veya 0x0001-0x00FF arası özel ID kullanabilirsiniz');
        _dataController.add('=== Company ID Değiştirme Bilgisi ===');
      }
    } catch (e) {
      print('Company ID bilgi hatası: $e');
    }
  }

  /// Company ID yakalama ve güncelleme önerisi
  Future<void> captureAndSuggestCompanyIdUpdate() async {
    try {
      if (!isConnected) {
        print('ESP bağlantısı yok, company ID yakalama atlanıyor');
        return;
      }

      // Manufacturer data'yı oku
      final manufacturerData = await _ble.readCharacteristic(_readCharacteristic!);
      
      // Debug: Tüm manufacturer data'yı göster
      print('Manufacturer Data Uzunluğu: ${manufacturerData.length}');
      print('Manufacturer Data Bytes: ${manufacturerData.map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}').join(' ')}');
      
      if (manufacturerData.length >= 2) {
        final companyId = (manufacturerData[0] << 8) | manufacturerData[1];
        final companyIdHex = '0x${companyId.toRadixString(16).padLeft(4, '0').toUpperCase()}';
        
        // Debug bilgisi ekle
        _dataController.add('=== Company ID Debug Bilgisi ===');
        _dataController.add('Manufacturer Data Uzunluğu: ${manufacturerData.length}');
        _dataController.add('Manufacturer Data: ${manufacturerData.map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}').join(' ')}');
        _dataController.add('İlk 2 Byte: 0x${manufacturerData[0].toRadixString(16).padLeft(2, '0').toUpperCase()} 0x${manufacturerData[1].toRadixString(16).padLeft(2, '0').toUpperCase()}');
        _dataController.add('Company ID: $companyIdHex ($companyId)');
        _dataController.add('=== Company ID Debug Bilgisi ===');
        
        // Company ID analizi ve güncelleme önerisi
        String updateSuggestion = '';
        if (companyId == 0x0000) {
          updateSuggestion = 'ÖNERİ: Company ID değiştirilebilir (şu anda: $companyIdHex)';
          _dataController.add('=== Company ID 0x1800 Güncelleme Önerisi ===');
          _dataController.add('Mevcut Company ID: $companyIdHex (ESP/Generic)');
          _dataController.add('Hedef Company ID: 0x1800 (Test ID)');
          _dataController.add('');
          _dataController.add('ESP32/ESP8266 Güncelleme Kodu:');
          _dataController.add('uint8_t manufacturer_data[] = {0x18, 0x00, 0x56, 0x78};');
          _dataController.add('esp_ble_adv_data_t adv_data = {');
          _dataController.add('    .set_scan_rsp = false,');
          _dataController.add('    .include_name = true,');
          _dataController.add('    .include_txpower = true,');
          _dataController.add('    .min_interval = 0x0006,');
          _dataController.add('    .max_interval = 0x0010,');
          _dataController.add('    .appearance = 0x00,');
          _dataController.add('    .manufacturer_len = 4,');
          _dataController.add('    .p_manufacturer_data = manufacturer_data,');
          _dataController.add('};');
          _dataController.add('esp_ble_gap_config_adv_data(&adv_data);');
          _dataController.add('');
          _dataController.add('Arduino IDE Kodu:');
          _dataController.add('BLEDevice::init("ESP32");');
          _dataController.add('BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();');
          _dataController.add('pAdvertising->setManufacturerData(0x1800, data, length);');
          _dataController.add('=== Company ID 0x1800 Güncelleme Önerisi ===');
        } else if (companyId >= 0x0001 && companyId <= 0x00FF) {
          updateSuggestion = 'Company ID zaten özel: $companyIdHex - Değiştirilmiş!';
          _dataController.add('=== Company ID Analizi ===');
          _dataController.add('Mevcut Company ID: $companyIdHex (Özel ID - Değiştirilmiş)');
          _dataController.add('Durum: Company ID başarıyla değiştirilmiş');
          _dataController.add('Güncelleme: Gerekmiyor - Zaten özel ID kullanılıyor');
          _dataController.add('=== Company ID Analizi ===');
        } else if (companyId == 0x004C) {
          updateSuggestion = 'Company ID Apple: $companyIdHex';
          _dataController.add('Company ID Apple: $companyIdHex - Resmi Apple ID');
        } else if (companyId == 0x0075) {
          updateSuggestion = 'Company ID Samsung: $companyIdHex';
          _dataController.add('Company ID Samsung: $companyIdHex - Resmi Samsung ID');
        } else if (companyId == 0x00E0) {
          updateSuggestion = 'Company ID Google: $companyIdHex';
          _dataController.add('Company ID Google: $companyIdHex - Resmi Google ID');
        } else if (companyId == 0x0006) {
          updateSuggestion = 'Company ID Microsoft: $companyIdHex';
          _dataController.add('Company ID Microsoft: $companyIdHex - Resmi Microsoft ID');
        } else if (companyId == 0x1800) {
          updateSuggestion = 'Company ID Test: $companyIdHex - Özel Test ID';
          _dataController.add('=== Company ID Test Analizi ===');
          _dataController.add('Mevcut Company ID: $companyIdHex (Test ID)');
          _dataController.add('Durum: Özel test company ID kullanılıyor');
          _dataController.add('Güncelleme: Gerekmiyor - Test ID başarıyla ayarlanmış');
          _dataController.add('Not: 0x1800 özel test ID olarak kullanılabilir');
          _dataController.add('=== Company ID Test Analizi ===');
        } else {
          updateSuggestion = 'Company ID resmi: $companyIdHex';
          _dataController.add('Company ID resmi: $companyIdHex - Bilinen resmi ID');
        }
        
        print('Company ID yakalandı: $companyIdHex - $updateSuggestion');
      } else {
        _dataController.add('HATA: Manufacturer data çok kısa (${manufacturerData.length} byte)');
      }
    } catch (e) {
      print('Company ID yakalama hatası: $e');
      if (!_dataController.isClosed) {
        _dataController.add('Company ID Yakalama Hatası: $e');
      }
    }
  }

  /// 3 saniyede bir otomatik yenileme başlat
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (isConnected && _readCharacteristic != null) {
        print('3 saniye otomatik yenileme - ESP\'den veri okunuyor...');
        _readDataPeriodically();
      } else {
        print('3 saniye otomatik yenileme - Bağlantı yok, timer durduruluyor');
        timer.cancel();
      }
    });
    
    if (!_dataController.isClosed) {
      _dataController.add('=== 3 SANİYE OTOMATİK YENİLEME BAŞLATILDI ===');
      _dataController.add('ESP cihazından 3 saniyede bir veri okunacak');
      _dataController.add('Bağlantı kesilirse otomatik yenileme duracak');
      _dataController.add('==========================================');
    }
  }

  /// Periyodik veri okuma
  Future<void> _readDataPeriodically() async {
    if (!isConnected || _readCharacteristic == null) {
      print('Periyodik okuma: Bağlantı yok veya characteristic bulunamadı');
      return;
    }

    if (_isDemoMode) {
      // Mock Data 
      final data = Uint8List.fromList([0x01, 0x02, 0x03, 0x04, DateTime.now().second]);
      final hexString = data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
      
      print('Periyodik Demo Okuma - Length: ${data.length}');
      
      if (!_numberController.isClosed) {
        _numberController.add(data);
      }
      
      if (!_dataController.isClosed) {
        _dataController.add('=== 3 SANİYE DEMO OKUMA (${data.length} Byte) ===');
        _dataController.add('HEX: $hexString');
        _dataController.add('==========================================');
      }
      return;
    }

    try {
      print('3 saniye periyodik okuma başlatıldı...');
      
      // READ işlemi yap
      final data = await _ble.readCharacteristic(_readCharacteristic!);
      print('Periyodik okuma - ${data.length} byte alındı');
      
      // Tüm format türlerini hazırla
      final hexString = data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
      final binaryString = data.map((byte) => byte.toRadixString(2).padLeft(8, '0')).join(' ');
      final intString = data.map((byte) => byte.toString()).join(', ');
      final byteString = data.toString();
      
      // String dönüşümü
      String stringData = '';
      try {
        stringData = String.fromCharCodes(data);
      } catch (e) {
        stringData = 'String dönüşümü başarısız: $e';
      }
      
      print('Periyodik Okuma - Hex: $hexString');
//      print('Periyodik Okuma - Binary: $binaryString');
//      print('Periyodik Okuma - Int: $intString');
//      print('Periyodik Okuma - Byte: $byteString');
//      print('Periyodik Okuma - String: $stringData');
      
      // Number stream'e byte array gönder
      if (!_numberController.isClosed) {
        _numberController.add(data);
      }
      
      // Data stream'e tüm formatları gönder
      if (!_dataController.isClosed) {
        _dataController.add('=== 3 SANİYE PERİYODİK OKUMA (${data.length} Byte) ===');
        _dataController.add('HEX: $hexString');
  //      _dataController.add('BINARY: $binaryString');
  //      _dataController.add('INT: $intString');
  //      _dataController.add('BYTE: $byteString');
  //      _dataController.add('STRING: $stringData');
        _dataController.add('==========================================');
      }
    } catch (e) {
      print('Periyodik okuma hatası: $e');
      if (!_dataController.isClosed) {
        _dataController.add('Periyodik Okuma Hatası: $e');
      }
    }
  }

  Future<void> disconnect() async {
    await _connectionSubscription?.cancel();
    _autoRefreshTimer?.cancel();
    _connectionState = DeviceConnectionState.disconnected;
    if (!_connectionController.isClosed) {
      _connectionController.add(_connectionState);
    }
  }

  // Getters
  bool get isConnected => _connectionState == DeviceConnectionState.connected;
  Stream<DeviceConnectionState> get connectionStream => _connectionController.stream;
  Stream<String> get messageStream => _messageController.stream;
  Stream<List<int>> get numberStream => _numberController.stream;
  Stream<String> get dataStream => _dataController.stream;

  void dispose() {
    _connectionSubscription?.cancel();
    _autoRefreshTimer?.cancel();
    
    if (!_connectionController.isClosed) {
      _connectionController.close();
    }
    if (!_messageController.isClosed) {
      _messageController.close();
    }
    if (!_numberController.isClosed) {
      _numberController.close();
    }
    if (!_dataController.isClosed) {
      _dataController.close();
    }
  }
}