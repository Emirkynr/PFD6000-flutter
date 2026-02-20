import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'dart:typed_data';

class BleDeviceModel {
  final String id;
  final String name;
  final int rssi;
  final Map<int, Uint8List> manufacturerData;
  final List<Uuid> serviceUuids;
  final bool isConnectable;

  const BleDeviceModel({
    required this.id,
    required this.name,
    required this.rssi,
    required this.manufacturerData,
    required this.serviceUuids,
    required this.isConnectable,
  });

  factory BleDeviceModel.fromDiscoveredDevice(DiscoveredDevice device) {
    Map<int, Uint8List> manufacturerMap = {};

    try {
      final dynamic rawData = device.manufacturerData;

      if (rawData is Uint8List) {
        manufacturerMap[0] = rawData;
      } else if (rawData is Map<int, List<int>>) {
        for (var entry in rawData.entries) {
          manufacturerMap[entry.key] = Uint8List.fromList(entry.value);
        }
      } else if (rawData is Map) {
        for (var entry in rawData.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key is int && value is List) {
            try {
              manufacturerMap[key] = Uint8List.fromList(List<int>.from(value));
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      print('BleDeviceModel: ManufacturerData parse error: $e');
    }

    return BleDeviceModel(
      id: device.id,
      name: device.name,
      rssi: device.rssi,
      manufacturerData: manufacturerMap,
      serviceUuids: device.serviceUuids,
      isConnectable: device.connectable == Connectable.available,
    );
  }

  @override
  String toString() => 'BleDeviceModel(id: $id, name: $name, rssi: $rssi)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BleDeviceModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
