import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../ble/ble_service.dart';

class MessageLogPage extends StatefulWidget {
  final DiscoveredDevice device;
  final BleService bleService;

  const MessageLogPage({
    super.key,
    required this.device,
    required this.bleService,
  });

  @override
  State<MessageLogPage> createState() => _MessageLogPageState();
}

class _MessageLogPageState extends State<MessageLogPage> {
  final List<MessageLog> _messageLogs = [];
  StreamSubscription? _dataSubscription;
  bool _isConnected = false;
  String _selectedFormat = 'HEX';
  bool _showRawData = true;

  @override
  void initState() {
    super.initState();
    _setupDataListener();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  void _setupDataListener() {
    // numberStream: ESP notification'dan gelen byte array'i dinle
    _dataSubscription = widget.bleService.numberStream.listen((byteData) {
      if (byteData.isNotEmpty) {
        // Byte array'i string'e çevir (görüntüleme için)
        final stringData = String.fromCharCodes(byteData);
        final hexData = byteData.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        
        setState(() {
          _messageLogs.insert(0, MessageLog(
            timestamp: DateTime.now(),
            type: 'ESP Notify',
            content: 'String: "$stringData"\nHex: $hexData\nBytes: ${byteData.length}',
            isIncoming: true,
          ));
          
          // Maksimum limit YOK - tüm mesajları tut
        });
      }
    });
  }

  Future<void> _connectToDevice() async {
    try {
      setState(() => _isConnected = true);
      
      final success = await widget.bleService.connectToDevice(widget.device.id);
      if (success) {
        await widget.bleService.discoverServices(widget.device.id);
        // Bağlantı başarılı, ESP notification'ları dinleniyor
      } else {
        setState(() => _isConnected = false);
      }
    } catch (e) {
      setState(() => _isConnected = false);
    }
  }

  Future<void> _disconnectFromDevice() async {
    try {
      await widget.bleService.disconnect();
      setState(() => _isConnected = false);
    } catch (e) {
      // Hata sessizce yut
    }
  }

  /// Kart konfigürasyonu işlemi (test sayfası için)
  Future<void> _configureCard() async {
    try {
      // Kart konfigürasyon mesajını binary formatında gönder
      final configMessage = "0x69,0x7D,0x63,0x30,0xC1,0xA3,0xF4,0x79,0xDB,0x5B,0x3E,0xF0,0x52,0xDF,0x7D,0xC6,0xAE,0xE8,0x47,0x3C,0xEB,0xA2,0xA5,0x6C,0xD6,0xF8,0xB6,0x28,0x05,0x68,0x32,0x38";
      
      // Hex mesajını binary byte array'e çevir
      final binaryData = _hexStringToBinaryBytes(configMessage);
      
      // Binary mesajı gönder
      await widget.bleService.sendBinaryMessage(binaryData);
      
      // ESP'den gelen notification'lar otomatik olarak görünecek
      
    } catch (e) {
      print('Kart konfigürasyonu hatası: $e');
    }
  }

  /// Hex string'i binary byte array'e çevir
  List<int> _hexStringToBinaryBytes(String hexString) {
    try {
      // Virgülle ayrılmış hex değerlerini al
      final hexValues = hexString.split(',');
      final bytes = <int>[];
      
      for (final hexValue in hexValues) {
        // 0x prefix'ini kaldır
        final cleanHex = hexValue.trim().replaceAll('0x', '');
        // Hex'i int'e çevir
        final byteValue = int.parse(cleanHex, radix: 16);
        bytes.add(byteValue);
      }
      
      return bytes;
    } catch (e) {
      print('Hex string binary çevirme hatası: $e');
      return [];
    }
  }

  void _clearLogs() {
    setState(() {
      _messageLogs.clear();
    });
  }

  void _toggleRawDataView() {
    setState(() {
      _showRawData = !_showRawData;
    });
  }

  void _changeDataFormat(String format) {
    setState(() {
      _selectedFormat = format;
    });
  }

  String _formatRawData(String content, String format) {
    if (!_showRawData) return content;
    
    // Raw data formatlarını parse et
    if (content.contains('=== ESP Notification') || content.contains('=== ESP INDICATE')) {
      final lines = content.split('\n');
      for (final line in lines) {
        if (line.startsWith('$format:')) {
          return line.substring('$format:'.length).trim();
        }
      }
    }
    
    return content;
  }

  void _exportRawData() {
    final rawData = _messageLogs
        .where((log) => log.type == 'ESP Değer' && log.content.contains('HEX:'))
        .map((log) => _extractHexData(log.content))
        .where((hex) => hex.isNotEmpty)
        .join('\n');
    
    if (rawData.isNotEmpty) {
      // Tüm raw data'yı formatla
      final allRawData = _messageLogs
          .where((log) => log.type == 'ESP Değer' && log.content.contains('=== ESP'))
          .map((log) => _formatRawDataForExport(log.content))
          .join('\n\n');
      
      // Export dialog göster
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Raw Data Export'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Column(
              children: [
                const Text('Export edilecek raw data:'),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      allRawData,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
            ElevatedButton(
              onPressed: () {
                // Burada gerçek export işlemi yapılabilir
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Raw data export edildi'),
                    duration: Duration(seconds: 2),
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('Export Et'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export edilecek raw data bulunamadı'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatRawDataForExport(String content) {
    if (content.contains('=== ESP Notification') || content.contains('=== ESP INDICATE')) {
      final lines = content.split('\n');
      final timestamp = DateTime.now().toString();
      final header = '=== RAW DATA EXPORT - $timestamp ===';
      return '$header\n${lines.join('\n')}\n=== END RAW DATA ===';
    }
    return content;
  }

  String _extractHexData(String content) {
    final lines = content.split('\n');
    for (final line in lines) {
      if (line.startsWith('HEX:')) {
        return line.substring('HEX:'.length).trim();
      }
    }
    return '';
  }

  void _manualRefresh() {
    // Manuel yenileme artık gerekli değil, notification otomatik geliyor
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notify Hex Data - ${widget.device.name}'),
        // backgroundColor: Colors.blue, // Use Theme
        // foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.format_list_bulleted),
            tooltip: 'Data Formatı',
            onSelected: _changeDataFormat,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'HEX', child: Text('HEX Format')),
              const PopupMenuItem(value: 'BINARY', child: Text('BINARY Format')),
              const PopupMenuItem(value: 'INT', child: Text('INT Format')),
              const PopupMenuItem(value: 'BYTE', child: Text('BYTE Format')),
              const PopupMenuItem(value: 'STRING', child: Text('STRING Format')),
            ],
          ),
          IconButton(
            icon: Icon(_showRawData ? Icons.visibility_off : Icons.visibility),
            onPressed: _toggleRawDataView,
            tooltip: _showRawData ? 'Raw Data Gizle' : 'Raw Data Göster',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportRawData,
            tooltip: 'Raw Data Export',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _manualRefresh,
            tooltip: 'Manuel Yenile',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearLogs,
            tooltip: 'Logları Temizle',
          ),
        ],
      ),
      body: Column(
        children: [
          // Bağlantı durumu ve kontroller
          // Bağlantı durumu ve kontroller
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceVariant, // or surfaceContainer
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isConnected ? 'Bağlı' : 'Bağlı Değil',
                      style: TextStyle(
                        color: _isConnected ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (!_isConnected)
                      ElevatedButton.icon(
                        onPressed: _connectToDevice,
                        icon: const Icon(Icons.bluetooth),
                        label: const Text('Bağlan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    else ...[
                      ElevatedButton.icon(
                        onPressed: _configureCard,
                        icon: const Icon(Icons.credit_card),
                        label: const Text('Kart Konfigürasyonu'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _disconnectFromDevice,
                        icon: const Icon(Icons.bluetooth_disabled),
                        label: const Text('Bağlantıyı Kes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // Raw data format seçimi
                Row(
                  children: [
                    const Text('Format: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _selectedFormat,
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text('Raw Data: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _showRawData ? Colors.green.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _showRawData ? 'AÇIK' : 'KAPALI',
                        style: TextStyle(
                          color: _showRawData ? Colors.green.shade800 : Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Mesaj listesi
          Expanded(
            child: _messageLogs.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.radar,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'ESP Raw Data bekleniyor',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'ESP cihazı 3 saniyede bir raw data fırlatıyor\nHEX, BINARY, INT, BYTE, STRING formatlarında',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _messageLogs.length,
                    itemBuilder: (context, index) {
                      final log = _messageLogs[index];
                      return MessageLogTile(
                        log: log,
                        selectedFormat: _selectedFormat,
                        showRawData: _showRawData,
                        onFormatRawData: _formatRawData,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class MessageLog {
  final DateTime timestamp;
  final String type;
  final String content;
  final bool isIncoming;

  MessageLog({
    required this.timestamp,
    required this.type,
    required this.content,
    required this.isIncoming,
  });
}

class MessageLogTile extends StatelessWidget {
  final MessageLog log;
  final String selectedFormat;
  final bool showRawData;
  final String Function(String content, String format) onFormatRawData;

  const MessageLogTile({
    super.key,
    required this.log,
    required this.selectedFormat,
    required this.showRawData,
    required this.onFormatRawData,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık satırı
            Row(
              children: [
                Icon(
                  _getTypeIcon(log.type),
                  size: 16,
                  color: _getTypeColor(log.type),
                ),
                const SizedBox(width: 8),
                Text(
                  log.type,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getTypeColor(log.type),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(log.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Mesaj içeriği
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: log.isIncoming ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: log.isIncoming ? Theme.of(context).colorScheme.primary.withOpacity(0.3) : Theme.of(context).dividerColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showRawData && log.content.contains('=== ESP')) ...[
                    // Raw data format seçimi için özel görünüm
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.data_object, size: 16, color: Colors.orange.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Raw Data ($selectedFormat)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            onFormatRawData(log.content, selectedFormat),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Tüm formatları göster
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.format_list_bulleted, size: 16, color: Colors.grey.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Tüm Formatlar',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            log.content,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Normal mesaj görünümü
                    SelectableText(
                      log.content,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Ek bilgiler
            if (log.content.length > 50) ...[
              const SizedBox(height: 4),
              Text(
                'Uzunluk: ${log.content.length} karakter',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'ESP Değer':
        return Icons.radar;
      case 'ESP Sayı':
        return Icons.numbers;
      case 'System':
        return Icons.info;
      default:
        return Icons.message;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'ESP Değer':
        return Colors.blue;
      case 'ESP Sayı':
        return Colors.green;
      case 'System':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }
}
