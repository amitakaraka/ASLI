import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles token and user data storage
/// Uses secure storage with SharedPreferences fallback
class SecureStorageService {
  static SecureStorageService? _instance;
  static SecureStorageService get instance =>
      _instance ??= SecureStorageService._();

  SecureStorageService._();

  // Secure storage with encryption
  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'asli_secure_storage',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      accountName: 'asli_app',
    ),
  );

  // Keys for storage
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'current_user';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _fcmTokenKey = 'fcm_token';

  // SharedPreferences for non-sensitive data
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ==================== AUTH TOKEN ====================

  /// Save authentication token
  Future<void> saveToken(String token, {Duration? expiry}) async {
    try {
      await _secure.write(key: _tokenKey, value: token);
      if (expiry != null) {
        final expiryTime = DateTime.now().add(expiry).toIso8601String();
        await _secure.write(key: _tokenExpiryKey, value: expiryTime);
      }
    } catch (e) {
      // Fallback to SharedPreferences
      await _prefs?.setString(_tokenKey, token);
    }
  }

  /// Get stored authentication token
  Future<String?> getToken() async {
    try {
      return await _secure.read(key: _tokenKey) ?? _prefs?.getString(_tokenKey);
    } catch (e) {
      return _prefs?.getString(_tokenKey);
    }
  }

  /// Check if token exists
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Check if token is expired
  Future<bool> isTokenExpired() async {
    try {
      final expiryStr = await _secure.read(key: _tokenExpiryKey);
      if (expiryStr == null) return false; // No expiry set, assume valid
      final expiry = DateTime.parse(expiryStr);
      return DateTime.now().isAfter(expiry);
    } catch (e) {
      return false;
    }
  }

  /// Delete authentication token
  Future<void> deleteToken() async {
    try {
      await _secure.delete(key: _tokenKey);
      await _secure.delete(key: _tokenExpiryKey);
      await _secure.delete(key: _refreshTokenKey);
    } catch (e) {
      // Fallback
      _prefs?.remove(_tokenKey);
    }
  }

  // ==================== USER DATA ====================

  /// Save current user data
  Future<void> saveUser(Map<String, dynamic> user) async {
    try {
      final userJson = jsonEncode(user);
      await _secure.write(key: _userKey, value: userJson);
    } catch (e) {
      await _prefs?.setString(_userKey, jsonEncode(user));
    }
  }

  /// Get stored user data
  Future<Map<String, dynamic>?> getUser() async {
    try {
      final userJson =
          await _secure.read(key: _userKey) ?? _prefs?.getString(_userKey);
      if (userJson == null) return null;
      return jsonDecode(userJson) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Delete stored user data
  Future<void> deleteUser() async {
    try {
      await _secure.delete(key: _userKey);
    } catch (e) {
      _prefs?.remove(_userKey);
    }
  }

  // ==================== FCM TOKEN ====================

  /// Save FCM token for push notifications
  Future<void> saveFcmToken(String token) async {
    await _secure.write(key: _fcmTokenKey, value: token);
    await _prefs?.setString(_fcmTokenKey, token);
  }

  /// Get stored FCM token
  Future<String?> getFcmToken() async {
    try {
      return await _secure.read(key: _fcmTokenKey) ??
          _prefs?.getString(_fcmTokenKey);
    } catch (e) {
      return _prefs?.getString(_fcmTokenKey);
    }
  }

  // ==================== REFRESH TOKEN ====================

  /// Save refresh token
  Future<void> saveRefreshToken(String token) async {
    await _secure.write(key: _refreshTokenKey, value: token);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return await _secure.read(key: _refreshTokenKey);
  }

  // ==================== CLEAR ALL ====================

  /// Clear all stored data (logout)
  Future<void> clearAll() async {
    await deleteToken();
    await deleteUser();
    try {
      await _secure.deleteAll();
    } catch (e) {
      // Ignore secure storage errors on clear
    }
  }

  // ==================== USER PREFERENCES ====================

  /// Save a generic preference
  Future<void> setPreference(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  /// Get a generic preference
  String? getPreference(String key) {
    return _prefs?.getString(key);
  }

  /// Save boolean preference
  Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  /// Get boolean preference
  bool? getBool(String key) {
    return _prefs?.getBool(key);
  }
}
