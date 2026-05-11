import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  static const String _settingsBoxName = 'settings';
  static const String _cacheBoxName = 'cache';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'current_user';
  static const String _themeKey = 'theme_mode';
  static const String _onboardingKey = 'onboarding_complete';

  Box? _settings;
  Box? _cache;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();
    _settings = await Hive.openBox(_settingsBoxName);
    _cache = await Hive.openBox(_cacheBoxName);
    _initialized = true;
  }

  Future<void> setString(String key, String value) async {
    await _settings?.put(key, value);
  }

  String? getString(String key) {
    return _settings?.get(key);
  }

  Future<void> setJson(String key, Map<String, dynamic> value) async {
    await _settings?.put(key, jsonEncode(value));
  }

  Map<String, dynamic>? getJson(String key) {
    final data = _settings?.get(key);
    if (data == null) return null;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> setBool(String key, bool value) async {
    await _settings?.put(key, value);
  }

  bool? getBool(String key) {
    final value = _settings?.get(key);
    if (value is bool) return value;
    if (value is int) return value == 1;
    return null;
  }

  Future<void> remove(String key) async {
    await _settings?.delete(key);
  }

  Future<void> clear() async {
    await _settings?.clear();
  }

  Future<void> cacheData(String key, dynamic data, {Duration? ttl}) async {
    final entry = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'ttl': ttl?.inMilliseconds,
    };
    await _cache?.put(key, jsonEncode(entry));
  }

  dynamic getCachedData(String key) {
    final entry = _cache?.get(key);
    if (entry == null) return null;

    try {
      final decoded = jsonDecode(entry);
      final timestamp = decoded['timestamp'] as int;
      final ttl = decoded['ttl'] as int?;

      if (ttl != null) {
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age > ttl) {
          _cache?.delete(key);
          return null;
        }
      }

      return decoded['data'];
    } catch (_) {
      return null;
    }
  }

  Future<void> clearExpiredCache() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final keys = _cache?.keys.toList() ?? [];

    for (final key in keys) {
      try {
        final entry = jsonDecode(_cache?.get(key) ?? '');
        final timestamp = entry['timestamp'] as int;
        final ttl = entry['ttl'] as int?;

        if (ttl != null && (now - timestamp) > ttl) {
          await _cache?.delete(key);
        }
      } catch (_) {
        await _cache?.delete(key);
      }
    }
  }

  Future<void> clearAllCache() async {
    await _cache?.clear();
  }

  Future<void> saveAuthToken(String token) async {
    await setString(_tokenKey, token);
  }

  String? getAuthToken() {
    return getString(_tokenKey);
  }

  Future<void> saveCurrentUser(Map<String, dynamic> user) async {
    await setJson(_userKey, user);
  }

  Map<String, dynamic>? getCurrentUser() {
    return getJson(_userKey);
  }

  Future<void> setThemeMode(bool isDark) async {
    await setBool(_themeKey, isDark);
  }

  bool? getThemeMode() {
    return getBool(_themeKey);
  }

  Future<void> setOnboardingComplete(bool complete) async {
    await setBool(_onboardingKey, complete);
  }

  bool? isOnboardingComplete() {
    return getBool(_onboardingKey);
  }

  Future<void> clearAuth() async {
    await remove(_tokenKey);
    await remove(_userKey);
  }
}

final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});

final cacheInitProvider = FutureProvider<bool>((ref) async {
  final cache = ref.read(cacheServiceProvider);
  await cache.init();
  return true;
});

final cachedUserProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final cache = ref.read(cacheServiceProvider);
  await cache.init();
  return cache.getCurrentUser();
});
