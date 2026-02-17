import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Favori kapilar ve son kullanilan kapi yonetimi
class FavoritesService {
  static const _lastDeviceIdKey = 'last_used_device_id';
  static const _lastDeviceNameKey = 'last_used_device_name';
  static const _favoritesKey = 'favorite_devices';

  // Cache
  static String? _cachedLastDeviceId;
  static List<FavoriteDevice>? _cachedFavorites;

  /// Son kullanilan cihazi kaydet
  static Future<void> saveLastDevice(String id, String name) async {
    _cachedLastDeviceId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDeviceIdKey, id);
    await prefs.setString(_lastDeviceNameKey, name);
  }

  /// Son kullanilan cihaz ID'sini al
  static Future<String?> getLastDeviceId() async {
    if (_cachedLastDeviceId != null) return _cachedLastDeviceId;
    final prefs = await SharedPreferences.getInstance();
    _cachedLastDeviceId = prefs.getString(_lastDeviceIdKey);
    return _cachedLastDeviceId;
  }

  /// Favori ekle/cikar (toggle)
  static Future<bool> toggleFavorite(String id, String name) async {
    final favorites = await getFavorites();
    final index = favorites.indexWhere((f) => f.id == id);
    if (index >= 0) {
      favorites.removeAt(index);
    } else {
      favorites.add(FavoriteDevice(id: id, name: name));
    }
    _cachedFavorites = favorites;
    final prefs = await SharedPreferences.getInstance();
    final json = favorites.map((f) => f.toJson()).toList();
    await prefs.setString(_favoritesKey, jsonEncode(json));
    return index < 0; // true = eklendi, false = cikarildi
  }

  /// Favori mi kontrolu
  static Future<bool> isFavorite(String id) async {
    final favorites = await getFavorites();
    return favorites.any((f) => f.id == id);
  }

  /// Tum favorileri al
  static Future<List<FavoriteDevice>> getFavorites() async {
    if (_cachedFavorites != null) return _cachedFavorites!;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_favoritesKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      _cachedFavorites = [];
      return [];
    }
    final List<dynamic> json = jsonDecode(jsonStr);
    _cachedFavorites = json.map((j) => FavoriteDevice.fromJson(j)).toList();
    return _cachedFavorites!;
  }

  /// Favori ID listesini al (hizli lookup icin)
  static Future<Set<String>> getFavoriteIds() async {
    final favorites = await getFavorites();
    return favorites.map((f) => f.id).toSet();
  }

  /// Preload (initState'te cagir)
  static Future<void> preload() async {
    await getLastDeviceId();
    await getFavorites();
  }
}

class FavoriteDevice {
  final String id;
  final String name;

  FavoriteDevice({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory FavoriteDevice.fromJson(Map<String, dynamic> json) {
    return FavoriteDevice(id: json['id'], name: json['name']);
  }
}
