import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:sprintf/sprintf.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import '../globals.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

/// BLE cihaz tarama ve yönetim sınıfı
/// Singleton pattern - splash ve scanner page arasinda tarama sonuclarini korur
class BleManager {
  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;
  BleManager._internal();

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  
  // Stream controller - bulunan cihazların listesini broadcast eder
  final StreamController<List<DiscoveredDevice>> _deviceController =
      StreamController<List<DiscoveredDevice>>.broadcast();

  // Public stream - UI dinleyicileri için
  Stream<List<DiscoveredDevice>> get devicesStream => _deviceController.stream;

  // İç veri yapıları
  final Map<String, DiscoveredDevice> _devicesMap = {}; // Hızlı erişim için Map
  final Map<String, DateTime> _deviceLastSeen = {}; // Staleness kontrolu icin
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  bool _isScanning = false;

  // Getter
  bool get isScanning => _isScanning;

  /// ✅ BLE taramayı başlat
  /// [nameStartsWith]: Cihaz isminin başlangıcına göre filtrele (opsiyonel)
  /// [withServices]: Belirli servisleri olan cihazları tara (opsiyonel)
  /// [manufacturerId]: Manufacturer ID ile filtrele (opsiyonel)
  /// [scanMode]: Tarama modu (default: lowLatency)
  void startScan({
    String? nameStartsWith,
    List<String>? withServices,
    int? manufacturerId,
    ScanMode scanMode = ScanMode.lowLatency,
  }) {
    // Zaten tarama yapılıyorsa durdur
    if (_isScanning) {
      debugPrint('BLE: Mevcut tarama durduruluyor...');
      stopScan();
    }


///    int rn;
///    rn=12345678;
///    String md5seed = sprintf('Poli%08dteknik', [rn]);
///    debugPrint('MD5 TEST: --------------------------------------.${rn}/${md5seed}');
///    var md5 = crypto.md5;
///    var content = new Utf8Encoder().convert(md5seed);
///    var digest = md5.convert(content);
///    String md5s1=hex.encode(digest.bytes);
///    String md5s=md5.convert(utf8.encode(md5seed)).toString();
///    String md5bytes = sprintf('%02X.%02X.%02X', [digest.bytes[0],digest.bytes[1],digest.bytes[2]]);
///    debugPrint('MD5 : ${md5s}/${md5s1}/${md5bytes}');

    DateTime now = DateTime.now();
    String formattedDate = DateFormat('kk:mm:ss EEE d MMM').format(now);
    debugPrint('BLE: ------------------------------${formattedDate}.');
    debugPrint('BLE: Tarama başlatılıyor... (nameFilter: $nameStartsWith, manufacturerId: ${manufacturerId != null ? '0x${manufacturerId.toRadixString(16).toUpperCase()}' : 'None'})');
    _isScanning = true;
    // Staleness kontrolu: 30sn icerisinde gorulmeyenleri temizle
    _devicesMap.removeWhere((id, _) {
      final lastSeen = _deviceLastSeen[id];
      if (lastSeen == null) return true;
      return now.difference(lastSeen).inSeconds > 30;
    });
    _deviceLastSeen.removeWhere((id, _) => !_devicesMap.containsKey(id));

//    debugPrint('BLE: Filtrele - mfID=${manufacturerId}.');
//    PermissionStatus locationPermission =  Permission.location.request();
//    PermissionStatus bleScan =  Permission.bluetoothScan.request();
//    PermissionStatus bleConnect =  Permission.bluetoothConnect.request();

    try {
      // Servis UUID'lerini parse et
      List<Uuid> serviceUuids = [];
      if (withServices != null && withServices.isNotEmpty) {
        serviceUuids = withServices
            .map((uuid) {
              try {
                return Uuid.parse(uuid);
              } catch (e) {
                debugPrint('BLE: UUID parse hatası: $uuid - $e');
                return null;
              }
            })
            .whereType<Uuid>()
            .toList();
      }

      // Taramayı başlat
      _scanSubscription = _ble.scanForDevices(
        withServices: serviceUuids,
        scanMode: scanMode,
      ).listen(
        (device) {
          // İsim filtresi uygula
          if (nameStartsWith != null && nameStartsWith.isNotEmpty) {
            if (!device.name.toLowerCase().startsWith(nameStartsWith.toLowerCase())) {
              return; // Filtreye uymayan cihazı atla
            }
          }

          if ( device.manufacturerData.isNotEmpty )
          {
            final devicesList = _devicesMap.values.toList();
            final int itemCount= devicesList.length;
            int i;
            int devOk=0;
  //          debugPrint('BLE: CHECK POLITEKNIK DEVICE IF IN LIST (${itemCount})');
            for(i=0;i<itemCount;i++)
              {
                final deviceM = devicesList[i];
                if ( deviceM.id == device.id )
                  {
//                    debugPrint('BLE: POLITEKNIK DEVICE IN LIST');
                    devOk=1;
                  }
                else
                {
//                  debugPrint('BLE: devName="${deviceM.name}",devID=${deviceM.id}');
                }
              }

            if ( devOk == 1 ) // Found
              {
//                debugPrint('BLE: POLITEKNIK DEVICE FOUND ALREADY EXISTS');
              }
            else
              {
                if ( device.manufacturerData[0] == 117 && device.manufacturerData[1] == 0 )
                {
//              debugPrint('BLE: SAMSUNG DEVICE FOUND');
                }
                if ( device.manufacturerData[0] == 80 && device.manufacturerData[1] == 84 ) {
                  if (device.manufacturerData[4] == 80 &&
                      device.manufacturerData[5] == 84) {

                    Uint8List bytes = device.manufacturerData.sublist(6, 14);
                    Uint8List dnamel = device.manufacturerData.sublist(14);
                    String rn = String.fromCharCodes(bytes);
                    String dname = String.fromCharCodes(dnamel);
                    debugPrint('BLE: POLITEKNIK DEVICE FOUND DName=${dname},rn=${rn}');
                    String md5seed = sprintf('Poli%steknik', [rn]);
                    var md5 = crypto.md5;
                    var content = new Utf8Encoder().convert(md5seed);
                    var digest = md5.convert(content);
//                    String md5s1 = hex.encode(digest.bytes);
                    String md5s = md5.convert(utf8.encode(md5seed)).toString();
//                    String md5bytes = sprintf('%02X.%02X.%02X',
//                        [digest.bytes[0], digest.bytes[1], digest.bytes[2]]);
                    debugPrint('MD5 : ${md5s}');
//                 List<int> newMD5=[];
                    newMD5.clear();
                    newMD5.addAll(digest.bytes);
//                 newMD5=digest.bytes;
                  }

                  String sentence1 = sprintf(
                      'Epoch Time= %d seconds ago.', [DateTime
                      .now()
                      .millisecondsSinceEpoch
                  ]);
//            debugPrint(sentence1);
                  debugPrint(sentence1 + ' = ${DateTime
                      .now()
                      .millisecondsSinceEpoch}');
//                  debugPrint('BLE: Cihaz bulundu - ${device.name} (${device
//                      .id}) RSSI: ${device.rssi} mfID=${device
//                      .manufacturerData}');
                  // Cihazı map'e ekle veya güncelle
                  _devicesMap[device.id] = device;
                  _deviceLastSeen[device.id] = DateTime.now();

                  // UI'ı güncelle
                  if (!_deviceController.isClosed) {
                    _deviceController.add(_devicesMap.values.toList());
                  }
                  debugPrint('BLE: Bulundu - ${device.name} (${device.id}) RSSI: ${device.rssi}');
                }
            }
          }
          // Manufacturer ID filtresi uygula
          if (manufacturerId != null) {
            if (!_hasManufacturerId(device, manufacturerId)) {
              return; // Manufacturer ID'ye uymayan cihazı atla
            }
          }

          if (manufacturerId == null) {
//              debugPrint('BLE: manufacturerId null, cihaz bulundu - ${device.name} (${device.id}) RSSI: ${device.rssi} mfID=${device.manufacturerData}');
              return; // Manufacturer ID yoksa atla
          }
          // Cihazı map'e ekle veya güncelle
          _devicesMap[device.id] = device;
          _deviceLastSeen[device.id] = DateTime.now();

          // UI'ı güncelle
          if (!_deviceController.isClosed) {
            _deviceController.add(_devicesMap.values.toList());
          }

          debugPrint('BLE: Filtrelenmiş cihaz bulundu - ${device.name} (${device.id}) RSSI: ${device.rssi}');
        },
        onError: (error) {
          debugPrint('BLE: Tarama hatası - $error');
          _isScanning = false;
        },
        onDone: () {
          debugPrint('BLE: Tarama tamamlandı');
          _isScanning = false;
        },
        cancelOnError: false, // Hata durumunda taramayı otomatik kapatma
      );
    } catch (e) {
      debugPrint('BLE: Tarama başlatma hatası - $e');
      _isScanning = false;
    }
  }

  /// ✅ BLE taramayı durdur
  Future<void> stopScan() async {
    if (!_isScanning) {
      //PermissionStatus locationPermission =
      await Permission.location.request();
      //PermissionStatus bleScan =
      await Permission.bluetoothScan.request();
      //PermissionStatus bleConnect =
      await Permission.bluetoothConnect.request();
      debugPrint('BLE: Tarama zaten durmuş durumda');
      return;
    }

    debugPrint('BLE: Tarama durduruluyor...');
    _isScanning = false;

    try {
      //PermissionStatus locationPermission =
      await Permission.location.request();
      //PermissionStatus bleScan =
      await Permission.bluetoothScan.request();
      //PermissionStatus bleConnect =
      await Permission.bluetoothConnect.request();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      debugPrint('BLE: Tarama başarıyla durduruldu');
    } catch (e) {
      debugPrint('BLE: Tarama durdurma hatası - $e');
    }
  }

  /// ✅ Cihaz listesini temizle
  void clearDevices() {
    debugPrint('BLE: Cihaz listesi temizleniyor');
    _devicesMap.clear();
    if (!_deviceController.isClosed) {
      _deviceController.add([]);
    }
  }

  /// ✅ İsme göre cihaz ara
  /// [deviceName]: Aranacak cihaz ismi (case-insensitive)
  /// Returns: Bulunan cihaz veya null
  DiscoveredDevice? findDeviceByName(String deviceName) {
    if (deviceName.isEmpty) return null;

    final searchName = deviceName.toLowerCase();
    
    for (var device in _devicesMap.values) {
      if (device.name.toLowerCase().contains(searchName)) {
        debugPrint('BLE: Cihaz bulundu - ${device.name}');
        return device;
      }
    }

    debugPrint('BLE: Cihaz bulunamadı - $deviceName');
    return null;
  }

  /// ✅ ID'ye göre cihaz ara
  DiscoveredDevice? findDeviceById(String deviceId) {
    return _devicesMap[deviceId];
  }

  /// ✅ Tüm cihazları al (immutable kopya)
  List<DiscoveredDevice> getAllDevices() {
    return List.unmodifiable(_devicesMap.values);
  }

  /// ✅ Belirli bir RSSI değerinin üstündeki cihazları filtrele
  List<DiscoveredDevice> getDevicesByMinRssi(int minRssi) {
    return _devicesMap.values
        .where((device) => device.rssi >= minRssi)
        .toList();
  }

  /// ✅ Manufacturer ID kontrolü
  bool _hasManufacturerId(DiscoveredDevice device, int manufacturerId) {
    try {
      final dynamic manufacturerData = device.manufacturerData;
      
      // Uint8List tipindeyse manufacturer ID 0 kabul edilir
      if (manufacturerData is Uint8List) {
        if (manufacturerId == 0) {
          debugPrint('BLE: Manufacturer ID 0 (Uint8List) bulundu');
          return true;
        }
        return false;
      }
      
      // Map tipindeyse key kontrolü yap
      if (manufacturerData is Map) {
        for (var entry in manufacturerData.entries) {
          if (entry.key == manufacturerId) {
            debugPrint('BLE: Manufacturer ID bulundu - 0x${manufacturerId.toRadixString(16).toUpperCase()}');
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('BLE: Manufacturer ID kontrol hatası - $e');
      return false;
    }
  }

  /// ✅ Dispose - Kaynakları temizle
  Future<void> dispose() async {
    debugPrint('BLE: BleManager dispose ediliyor...');
    await stopScan();
    await _deviceController.close();
    _devicesMap.clear();
  }
}
