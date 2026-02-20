import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../ble/ble_service.dart';
import 'message_sender.dart';

/// Kart konfigürasyonu dinleyicisi
/// ESP32'den gelen kart numaralarını dinler (10 saniye timeout)
/// Config command'ı filtreler ve sadece 16/32 byte kart numaralarını kabul eder
class CardConfigHandler {
  final BleService bleService;
  final Function(List<int>) onCardReceived;
  final Function(String) onError;

  CardConfigHandler({
    required this.bleService,
    required this.onCardReceived,
    required this.onError,
  });

  StreamSubscription? _numberSubscription;

  /// Kart okumayı başlat
  /// 10 saniye timeout ile ESP32'den kart numarasını bekler
  /// Config command'ı görmezden gelir, sadece 16/32 byte kart numaralarını işler
  Future<void> startListening() async {
    try {
      _numberSubscription = bleService.numberStream.listen((cardBytes) {
        if (cardBytes.isEmpty) return;

        if (listEquals(cardBytes, MessageSender.configCommand)) {
          return;
        }

        if (cardBytes.length == 16 || cardBytes.length == 32) {
          onCardReceived(cardBytes);
          stopListening();
        }
      });

      Timer(const Duration(seconds: 10), () {
        if (_numberSubscription != null) {
          stopListening();
          onError('Kart okutma zaman aşımı');
        }
      });
    } catch (e) {
      print('Kart dinleme hatası: $e');
    }
  }

  /// Kart dinlemeyi durdur
  /// Stream subscription'ı iptal eder
  void stopListening() {
    _numberSubscription?.cancel();
    _numberSubscription = null;
  }
}
