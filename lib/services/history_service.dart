import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Kapi gecis gecmisi yonetimi
class HistoryService {
  static const _historyKey = 'gate_history';
  static const _maxEntries = 100;

  /// Yeni gecis kaydedi ekle
  static Future<void> addEntry({
    required String doorName,
    required String doorId,
    required String action, // "entry" or "exit"
    required bool success,
  }) async {
    final entry = HistoryEntry(
      doorName: doorName,
      doorId: doorId,
      action: action,
      timestamp: DateTime.now(),
      success: success,
    );

    final entries = await getEntries();
    entries.insert(0, entry);
    if (entries.length > _maxEntries) {
      entries.removeRange(_maxEntries, entries.length);
    }

    final prefs = await SharedPreferences.getInstance();
    final json = entries.map((e) => e.toJson()).toList();
    await prefs.setString(_historyKey, jsonEncode(json));
  }

  /// Tum gecis kayitlarini al
  static Future<List<HistoryEntry>> getEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_historyKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    final List<dynamic> json = jsonDecode(jsonStr);
    return json.map((j) => HistoryEntry.fromJson(j)).toList();
  }

  /// Gecmisi temizle
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}

class HistoryEntry {
  final String doorName;
  final String doorId;
  final String action;
  final DateTime timestamp;
  final bool success;

  HistoryEntry({
    required this.doorName,
    required this.doorId,
    required this.action,
    required this.timestamp,
    required this.success,
  });

  Map<String, dynamic> toJson() => {
        'doorName': doorName,
        'doorId': doorId,
        'action': action,
        'timestamp': timestamp.toIso8601String(),
        'success': success,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      doorName: json['doorName'] ?? '',
      doorId: json['doorId'] ?? '',
      action: json['action'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      success: json['success'] ?? false,
    );
  }
}
