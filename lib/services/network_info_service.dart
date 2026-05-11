import 'dart:io';
import 'package:flutter/foundation.dart';

class NetworkInfoService {
  static NetworkInfoService? _instance;
  static NetworkInfoService get instance =>
      _instance ??= NetworkInfoService._();

  NetworkInfoService._();

  String? _localIp;
  bool _scanned = false;

  String get localIp => _localIp ?? 'localhost';
  bool get hasLocalIp => _localIp != null;

  Future<String> getLocalIpAddress() async {
    if (_scanned && _localIp != null) return _localIp!;
    if (kIsWeb) {
      _localIp = 'localhost';
      _scanned = true;
      return _localIp!;
    }

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            _localIp = addr.address;
            _scanned = true;
            return _localIp!;
          }
        }
      }

      // Fallback: try to get from network interfaces
      final networkInterfaces = await NetworkInterface.list();
      for (final interface in networkInterfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            _localIp = addr.address;
            _scanned = true;
            return _localIp!;
          }
        }
      }
    } catch (e) {
      // Ignore errors, use fallback
    }

    _localIp = 'localhost';
    _scanned = true;
    return _localIp!;
  }

  void clearCache() {
    _localIp = null;
    _scanned = false;
  }
}
