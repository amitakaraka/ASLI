import 'package:flutter/foundation.dart';

/// App configuration

class EnvConfig {
  static String? _cachedApiBaseUrl;
  static String? _cachedWsUrl;

  /// Get API base URL based on platform and environment
  static String get apiBaseUrl {
    if (_cachedApiBaseUrl != null) return _cachedApiBaseUrl!;

    // Use localhost for web development, Render for mobile
    if (kIsWeb) {
      return _cachedApiBaseUrl = 'http://localhost:5050';
    }
    return _cachedApiBaseUrl = 'https://backend-eight-weld-88.vercel.app';
  }

  /// Get WebSocket URL based on API base URL
  static String get wsUrl {
    if (_cachedWsUrl != null) return _cachedWsUrl!;

    final base = apiBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    // Ensure proper Socket.IO path
    if (!base.endsWith('/socket.io')) {
      _cachedWsUrl = '$base/socket.io';
    } else {
      _cachedWsUrl = base;
    }

    return _cachedWsUrl!;
  }

  /// API version prefix
  static const String apiVersion = '';

  /// Full API URL with version
  static String get apiUrl => '$apiBaseUrl$apiVersion';

  // Timeouts - set high because Render free tier is slow to wake up
  static const Duration connectTimeout = Duration(seconds: 90);
  static const Duration receiveTimeout = Duration(seconds: 90);
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Retry configuration
  static const int maxRetries = 3;
  static const int retryDelayMs = 1000;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 2);

  /// Feature flags
  static const bool enableOfflineMode = true;
  static const bool enableLogging = kDebugMode;
  static const bool enableCache = true;

  /// Cache configuration
  static const Duration cacheDuration = Duration(minutes: 5);
  static const Duration shortCacheDuration = Duration(minutes: 1);
  static const Duration longCacheDuration = Duration(minutes: 30);

  /// WebSocket configuration
  static const Duration socketTimeout = Duration(seconds: 60);
  static const int socketReconnectAttempts = 5;
  static const Duration socketReconnectDelay = Duration(seconds: 1);
  static const Duration socketReconnectDelayMax = Duration(seconds: 5);

  /// Health check configuration
  static const Duration healthCheckInterval = Duration(seconds: 30);
  static const String healthEndpoint = '/health';

  /// Reset cached values (useful for testing)
  static void resetCache() {
    _cachedApiBaseUrl = null;
    _cachedWsUrl = null;
  }

  /// Check if running in debug mode
  static bool get isDebug => kDebugMode;

  /// Check if running in release mode
  static bool get isRelease => kReleaseMode;

  /// Check if running in profile mode
  static bool get isProfile => kProfileMode;
}

/// Build environment enumeration
enum BuildEnvironment { development, staging, production }

/// Build configuration helper
class BuildConfig {
  /// Get current build environment
  static BuildEnvironment get currentEnvironment {
    if (kDebugMode) return BuildEnvironment.development;
    if (kProfileMode) return BuildEnvironment.staging;
    return BuildEnvironment.production;
  }

  /// Get human-readable environment name
  static String get environmentName {
    switch (currentEnvironment) {
      case BuildEnvironment.development:
        return 'Development';
      case BuildEnvironment.staging:
        return 'Staging';
      case BuildEnvironment.production:
        return 'Production';
    }
  }

  /// Check if running in production
  static bool get isProduction =>
      currentEnvironment == BuildEnvironment.production;

  /// Check if running in development
  static bool get isDevelopment =>
      currentEnvironment == BuildEnvironment.development;

  /// Check if running in staging
  static bool get isStaging => currentEnvironment == BuildEnvironment.staging;

  /// Get API URL for current environment
  String get apiUrl {
    switch (currentEnvironment) {
      case BuildEnvironment.development:
        return 'http://localhost:5001/api';
      case BuildEnvironment.staging:
        return const String.fromEnvironment(
          'STAGING_API_URL',
          defaultValue: 'https://staging-api.asli-campus.com/api',
        );
      case BuildEnvironment.production:
        return const String.fromEnvironment(
          'PRODUCTION_API_URL',
          defaultValue: 'https://api.asli-campus.com/api',
        );
    }
  }
}
