import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../ble/ble_manager.dart';
import '../ble/ble_service.dart';
import 'scanner/widgets/door_status_banner.dart';
import 'scanner/widgets/device_list.dart';
import 'scanner/widgets/message_settings_drawer.dart';
import 'scanner/managers/card_manager.dart';
import 'scanner/managers/device_filter.dart';
import 'scanner/managers/connection_manager.dart';
import 'scanner/managers/message_sender.dart';
import 'scanner/managers/card_config_handler.dart';
import 'scanner/managers/card_config_handler.dart';
import 'message_log_page.dart';
import '../main.dart';
import '../theme/theme_provider.dart';

/// Ana tarayıcı sayfası - BLE cihaz tarama ve mesaj gönderme
/// Raw data'dan cihaz adı ve şifre çıkararak giriş/çıkış mesajları gönderir
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  // BLE servis yöneticileri
  final BleManager _bleManager = BleManager();
  final BleService _bleService = BleService();
  late final ConnectionManager _connectionManager;
  late final MessageSender _messageSender;
  CardConfigHandler? _cardConfigHandler;

  // UI durumları
  bool scanning = false;
  Timer? _scanAutoStopTimer;
  List<DiscoveredDevice> devices = [];
  List<int> newMD5 = [];
  final Map<String, bool> _deviceConnections = {};
  bool _buttonsDisabled = false;
  String _doorStatus = "";
  StreamSubscription<DeviceConnectionState>? _connectionStateSub;

  @override
  void initState() {
    super.initState();

    // Manager'ları başlat
    _connectionManager = ConnectionManager(
      bleService: _bleService,
      deviceConnections: _deviceConnections,
    );
    _messageSender = MessageSender(bleService: _bleService);

    // BLE cihaz taramasını dinle ve raw data 0x50 0x54 ile filtrele
    _bleManager.devicesStream.listen((list) {
      final filtered =
          list.where((device) => DeviceFilter.hasRawData5054(device)).toList();
      setState(() => devices = filtered);
    });

    // BLE bağlantı durumunu dinle
    _connectionStateSub = _bleService.connectionStream.listen((state) {
      if (!mounted) return;
      if (_connectionManager.currentDeviceId != null) {
        setState(() {
          _deviceConnections[_connectionManager.currentDeviceId!] =
              state == DeviceConnectionState.connected;
        });
      }
    });

    // Taramayı başlat
    _startScanWithAutoStop();
    _startContinuousScanning();
  }

  /// BLE taramasını başlat ve 20 saniye sonra durdur
  void _startScanWithAutoStop() {
    _bleManager.stopScan();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      _bleManager.startScan();
      setState(() => scanning = true);
      _scanAutoStopTimer?.cancel();
      _scanAutoStopTimer = Timer(const Duration(seconds: 20), () {
        if (!mounted) return;
        _bleManager.stopScan();
        setState(() => scanning = false);
      });
    });
  }

  /// Her 15 saniyede bir yeni tarama başlat
  void _startContinuousScanning() {
    Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _startScanWithAutoStop();
    });
  }

  /// Giriş mesajı gönder
  /// Raw data'dan şifre çıkarır ve mesaja ekler
  /// Mesaj formatı: [komut 16 byte] + [kart 16/32 byte] + [flag 0x00] + [şifre 8 byte]
  Future<void> _sendEntryMessage(String deviceId) async {
    if (_buttonsDisabled) return;

    print('Find Device');
    // Device'ı bul
    final device = devices.firstWhere((d) => d.id == deviceId);

    // Kayıtlı kart numarasını al
    print('Find Card');
    final cardBytes = await CardManager.getConfiguredCardNumber();
    if (cardBytes.isEmpty) return;

    final messageInfo = MessageSender.getEntryMessageInfo(cardBytes);

    // V2: No confirmation dialog - show immediate feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: const Text('Giriş işlemi başlatıldı...'),
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    print('Starting Entry Process');

    try {
      // Cihaza bağlan
      print('Connect Device');
      await _connectionManager.connectToDevice(deviceId);
      print('Connect Device delay');
      await Future.delayed(const Duration(milliseconds: 200));
      print('Connect Device delay done');

      // Mesajı gönder (şifre otomatik eklenir)
      print('Send Message');
      final success = await _messageSender.sendEntryMessage(cardBytes, device);
      print('Send Message Done');
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 2),
            content: Text('Hoş Geldiniz - Giriş mesajı gönderildi'),
            backgroundColor: Colors.green,
          ),
        );
        _disableButtonsTemporarily("Kapı açıldı (Giriş)");
      }
    } finally {
      await _connectionManager.disconnectFromDevice(deviceId);
    }
  }

  /// Çıkış mesajı gönder
  /// Raw data'dan şifre çıkarır ve mesaja ekler
  /// Mesaj formatı: [komut 16 byte] + [kart 16/32 byte] + [flag 0x01] + [şifre 8 byte]
  Future<void> _sendExitMessage(String deviceId) async {
    if (_buttonsDisabled) return;

    // Device'ı bul
    final device = devices.firstWhere((d) => d.id == deviceId);

    // Kayıtlı kart numarasını al
    final cardBytes = await CardManager.getConfiguredCardNumber();
    if (cardBytes.isEmpty) return;

    final messageInfo = MessageSender.getExitMessageInfo(cardBytes);

    // Kullanıcıya onay sor
    final confirmed = await _showExitMessageDialog(messageInfo);
    if (confirmed != true) return;

    try {
      // Cihaza bağlan
      await _connectionManager.connectToDevice(deviceId);
      await Future.delayed(const Duration(milliseconds: 500));

      // Mesajı gönder (şifre otomatik eklenir)
      final success = await _messageSender.sendExitMessage(cardBytes, device);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 2),
            content: Text('Kart numarası gönderildi - Çıkış'),
            backgroundColor: Colors.red,
          ),
        );
        _disableButtonsTemporarily("Kapı açıldı (Çıkış)");
      }
    } finally {
      await _connectionManager.disconnectFromDevice(deviceId);
    }
  }

  /// Kart konfigürasyonu - ESP32'den kart numarası al ve kaydet
  Future<void> _configureCard(String deviceId) async {
    if (_buttonsDisabled) return;

    try {
      await _connectionManager.connectToDevice(deviceId);
      await Future.delayed(const Duration(milliseconds: 500));

      // V2: Enhanced SnackBar feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: const Text(
                'Kart konfigürasyonu başlatılıyor... Lütfen kartı okuyucuya yaklaştırın'),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      await _messageSender.sendConfigMessage();

      _cardConfigHandler = CardConfigHandler(
        bleService: _bleService,
        onCardReceived: (cardBytes) async {
          await CardManager.saveCardToConfig(cardBytes);
          final displayString = CardManager.bytesToHexString(cardBytes);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 3),
                content: Text(
                    'Kart numarası kaydedildi (${cardBytes.length} byte):\n$displayString'),
                backgroundColor: Colors.green,
              ),
            );
          }
          await _connectionManager.disconnectFromDevice(deviceId);
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 2),
                content: Text(error),
                backgroundColor: Colors.orange,
              ),
            );
          }
          _connectionManager.disconnectFromDevice(deviceId);
        },
      );

      await _cardConfigHandler!.startListening();
    } catch (e) {
      await _connectionManager.disconnectFromDevice(deviceId);
    }
  }

  /// Giriş mesajı onay dialogu
  /// Mesaj detaylarını gösterir: komut, kart, flag, şifre, toplam byte
  Future<bool?> _showEntryMessageDialog(
      Map<String, dynamic> info, List<int> cardBytes) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Giriş Mesajı Gönder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gönderilecek mesaj:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Komut: 16 byte'),
            Text('  ${info['commandHex']}',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            const SizedBox(height: 4),
            Text('Kart: ${info['cardLength']} byte'),
            Text('  ${info['cardString']}',
                style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 4),
            const Text('Flag: 0x00 (Giriş)',
                style: TextStyle(fontSize: 11, color: Colors.blue)),
            const SizedBox(height: 4),
            const Text('Şifre: 8 byte',
                style: TextStyle(fontSize: 11, color: Colors.purple)),
            const SizedBox(height: 4),
            Text('Toplam: ${info['totalBytes'] + 8} byte',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Mesajı göndermek istiyor musunuz?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  /// Çıkış mesajı onay dialogu
  /// Mesaj detaylarını gösterir: komut, kart, flag (0x01), şifre, toplam byte
  Future<bool?> _showExitMessageDialog(Map<String, dynamic> info) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Mesajı Gönder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gönderilecek mesaj:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Komut: 16 byte'),
            const SizedBox(height: 4),
            Text('Kart: ${info['cardHex']}',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            Text('  STR: ${info['cardString']}',
                style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 4),
            const Text('Flag: 0x01 (Çıkış)',
                style: TextStyle(fontSize: 11, color: Colors.orange)),
            const SizedBox(height: 4),
            const Text('Şifre: 8 byte',
                style: TextStyle(fontSize: 11, color: Colors.purple)),
            const SizedBox(height: 4),
            Text('Toplam: ${info['totalBytes'] + 8 + 16} byte',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Mesajı göndermek istiyor musunuz?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  /// Butonları geçici olarak devre dışı bırak (6 saniye)
  /// Kapı açıldıktan sonra spam gönderimi engellemek için kullanılır
  void _disableButtonsTemporarily(String status) {
    setState(() {
      _buttonsDisabled = true;
      _doorStatus = status;
    });

    Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() {
        _buttonsDisabled = false;
        _doorStatus = "";
      });
      _refreshConnections();
    });
  }

  /// BLE bağlantılarını sıfırla
  /// Tüm cihaz bağlantılarını keser ve listeyi temizler
  void _refreshConnections() {
    _bleService.disconnect();
    setState(() {
      _deviceConnections.clear();
      _connectionManager.currentDeviceId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        content: Text('Poli BLE bağlantıları yenilendi'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  /// Mesaj log sayfasını aç
  /// Seçili cihazın detaylı mesaj loglarını gösterir
  void _showMessageLog(DiscoveredDevice device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessageLogPage(
          device: device,
          bleService: _bleService,
        ),
      ),
    );
  }

  /// Widget dispose - kaynakları temizle
  /// BLE bağlantıları, timer'lar ve subscription'ları iptal eder
  @override
  void dispose() {
    _bleManager.dispose();
    _bleService.dispose();
    _connectionStateSub?.cancel();
    _scanAutoStopTimer?.cancel();
    _cardConfigHandler?.stopListening();
    super.dispose();
  }

  /// UI build - ana ekran yapısı
  /// AppBar, Drawer (ayarlar), kapı durumu, cihaz listesi içerir
  @override
  Widget build(BuildContext context) {
    // Import MyApp for theme toggling
    // Note: Assuming MyApp is in main.dart which is usually imported or available.
    // If not, we might need to add the import line at top.

    return Scaffold(
      appBar: AppBar(
        title: const Text("POLITEKNIK BGS",
            style: TextStyle(fontWeight: FontWeight.bold)),
        // Remove hardcoded colors to use Theme
        // backgroundColor: const Color(0xFF1976D2),
        // foregroundColor: Colors.white,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          // Theme Toggle Button
          IconButton(
            icon: const Icon(Icons.brightness_medium_outlined),
            tooltip: 'Temayı Değiştir',
            onPressed: () {
              MyApp.of(context).toggleTheme();
            },
          ),
        ],
      ),
      drawer: const Drawer(
        child: MessageSettingsDrawer(),
      ),
      body: KeyedSubtree(
        key: ValueKey(Theme.of(context).brightness),
        child: Column(
          children: [
            DoorStatusBanner(doorStatus: _doorStatus),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _startScanWithAutoStop();
                  await Future.delayed(const Duration(milliseconds: 400));
                },
                child: DeviceList(
                  devices: devices,
                  deviceConnections: _deviceConnections,
                  buttonsDisabled: _buttonsDisabled,
                  onEntry: _sendEntryMessage,
                  onExit: _sendExitMessage,
                  onTest: _showMessageLog,
                  onCardConfig: _configureCard,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
