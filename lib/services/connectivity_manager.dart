import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

/// Connection state enumeration
enum NetConnectionState {
  connected,
  connecting,
  disconnected,
  lost, // Was connected but lost connection
  unavailable, // No network available
}

/// Network connectivity manager with real-time monitoring
/// Handles connection state changes, automatic reconnection, and health checks
class ConnectivityManager {
  static ConnectivityManager? _instance;
  static ConnectivityManager get instance => _instance ??= ConnectivityManager._();

  ConnectivityManager._();

  final Connectivity _connectivity = Connectivity();

  // Stream controllers for connection events
  final _stateController = StreamController<NetConnectionState>.broadcast();
  final _typeController = StreamController<ConnectivityResult>.broadcast();
  final _errorController = StreamController<ConnectionError>.broadcast();

  // Current state
  NetConnectionState _currentState = NetConnectionState.disconnected;
  ConnectivityResult _currentType = ConnectivityResult.none;
  DateTime? _lastSuccessfulCheck;

  // Connection listeners
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  // Retry configuration
  int _retryCount = 0;
  static const int _maxRetries = 5;
  static const Duration _baseRetryDelay = Duration(seconds: 2);
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _connectionTimeout = Duration(seconds: 90);

  // Callbacks
  void Function(NetConnectionState state)? onStateChange;
  Future<bool> Function()? onConnectionCheck;

  /// Stream of connection state changes
  Stream<NetConnectionState> get stateStream => _stateController.stream;

  /// Stream of connection type changes
  Stream<ConnectivityResult> get typeStream => _typeController.stream;

  /// Stream of connection errors
  Stream<ConnectionError> get errorStream => _errorController.stream;

  /// Current connection state
  NetConnectionState get state => _currentState;

  /// Current connection type
  ConnectivityResult get type => _currentType;

  /// Check if currently connected
  bool get isConnected => _currentState == NetConnectionState.connected;

  /// Check if currently connecting
  bool get isConnecting => _currentState == NetConnectionState.connecting;

  /// Check if currently disconnected
  bool get isDisconnected => 
      _currentState == NetConnectionState.disconnected || 
      _currentState == NetConnectionState.lost ||
      _currentState == NetConnectionState.unavailable;

  /// Get last successful connection time
  DateTime? get lastSuccessfulCheck => _lastSuccessfulCheck;

  /// Initialize connectivity monitoring
  Future<void> init({Future<bool> Function()? connectionCheck}) async {
    _log('Initializing ConnectivityManager...');
    onConnectionCheck = connectionCheck;

    // Check initial connectivity
    await _checkConnectivity();

    // Listen for changes
    try {
      _subscription = _connectivity.onConnectivityChanged.listen(
        _handleConnectivityChange,
        onError: (error) {
          _log('Connectivity stream error: $error', isError: true);
          _emitError(ConnectionErrorType.streamError, 'Connectivity stream error: $error');
        },
      );
    } catch (e) {
      _log('Failed to listen to connectivity changes: $e', isError: true);
      _emitError(ConnectionErrorType.streamError, 'Failed to listen: $e');
    }

    // Start heartbeat monitoring
    _startHeartbeat();
    
    _log('ConnectivityManager initialized. Initial state: $_currentState');
  }

  /// Handle connectivity change events
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      _log('Empty connectivity results', isError: true);
      return;
    }

    final result = results.first;
    _log('Connectivity changed: $result');
    
    if (_currentType != result) {
      _currentType = result;
      _typeController.add(result);
    }

    if (result == ConnectivityResult.none) {
      _updateState(NetConnectionState.disconnected);
    } else {
      // Connected - verify with actual API check
      _verifyConnection();
    }
  }

  /// Check actual connectivity
  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results);
    } catch (e) {
      _log('Connectivity check failed: $e', isError: true);
      _emitError(ConnectionErrorType.checkFailed, 'Connectivity check failed: $e');
      _updateState(NetConnectionState.unavailable);
    }
  }

  /// Verify connection with API
  Future<void> _verifyConnection() async {
    _updateState(NetConnectionState.connecting);

    try {
      // Use the connection check callback if provided
      if (onConnectionCheck != null) {
        final isConnected = await onConnectionCheck!();
        if (isConnected) {
          _onConnected();
          return;
        }
      }

      // Try to connect to API directly
      final result = await _pingApi();
      if (result) {
        _onConnected();
      } else {
        _updateState(NetConnectionState.disconnected);
      }
    } catch (e) {
      _log('Connection verification failed: $e', isError: true);
      _emitError(ConnectionErrorType.verificationFailed, 'Verification failed: $e');
      _updateState(NetConnectionState.disconnected);
    }
  }

  /// Ping the API to verify connection
  Future<bool> _pingApi() async {
    final healthUrl = '${EnvConfig.apiBaseUrl}${EnvConfig.healthEndpoint}';
    final fallbackUrl = EnvConfig.apiBaseUrl;
    
    try {
      // Try health endpoint first
      final client = http.Client();
      final response = await client
          .get(Uri.parse(healthUrl))
          .timeout(_connectionTimeout);
      client.close();
      
      if (response.statusCode == 200) {
        _lastSuccessfulCheck = DateTime.now();
        return true;
      }
    } catch (e) {
      _log('Health endpoint ping failed: $e');
    }

    // Fallback to root endpoint
    try {
      final client = http.Client();
      final response = await client
          .get(Uri.parse(fallbackUrl))
          .timeout(_connectionTimeout);
      client.close();
      
      if (response.statusCode == 200) {
        _lastSuccessfulCheck = DateTime.now();
        return true;
      }
    } catch (e) {
      _log('Root endpoint ping failed: $e');
    }

    return false;
  }

  /// Called when connection is established
  void _onConnected() {
    _retryCount = 0;
    _updateState(NetConnectionState.connected);
    _cancelReconnect();
    _log('Connection established successfully');
  }

  /// Called when connection is lost
  void _onDisconnected() {
    if (_currentState == NetConnectionState.connected) {
      _updateState(NetConnectionState.lost);
      _emitError(ConnectionErrorType.connectionLost, 'Connection lost');
    } else {
      _updateState(NetConnectionState.disconnected);
    }
    _scheduleReconnect();
  }

  /// Update connection state
  void _updateState(NetConnectionState state) {
    if (_currentState == state) return;

    final previousState = _currentState;
    _currentState = state;
    
    _log('State changed: $previousState -> $state');
    _stateController.add(state);
    onStateChange?.call(state);
  }

  /// Start heartbeat to monitor connection
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      if (_currentState == NetConnectionState.connected) {
        final isStillConnected = await _pingApi();
        if (!isStillConnected) {
          _log('Heartbeat check failed - connection lost');
          _onDisconnected();
        }
      }
    });
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_retryCount >= _maxRetries) {
      _log('Max retries reached ($_maxRetries). Stopping reconnection.', isError: true);
      _updateState(NetConnectionState.unavailable);
      _emitError(ConnectionErrorType.maxRetriesReached, 'Max reconnection attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    final delay = _baseRetryDelay * (1 << _retryCount); // Exponential backoff
    _retryCount++;

    _log('Scheduling reconnect attempt $_retryCount in ${delay.inSeconds}s');
    
    _reconnectTimer = Timer(delay, () {
      _log('Executing reconnect attempt $_retryCount');
      _checkConnectivity();
    });
  }

  /// Cancel scheduled reconnection
  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _retryCount = 0;
  }

  /// Try reconnecting
  Future<void> reconnect() async {
    _log('Force reconnect requested');
    _retryCount = 0;
    _cancelReconnect();
    _updateState(NetConnectionState.connecting);
    await _checkConnectivity();
  }

  /// Get human-readable connection type
  String get connectionTypeString {
    switch (_currentType) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.other:
        return 'Connected';
      case ConnectivityResult.none:
        return 'No Connection';
    }
  }

  /// Get connection quality score (0-100)
  int get connectionQuality {
    if (!isConnected) return 0;
    
    final now = DateTime.now();
    if (_lastSuccessfulCheck == null) return 50;
    
    final timeSinceLastSuccess = now.difference(_lastSuccessfulCheck!);
    if (timeSinceLastSuccess.inSeconds < 30) return 100;
    if (timeSinceLastSuccess.inSeconds < 60) return 80;
    if (timeSinceLastSuccess.inSeconds < 120) return 60;
    return 40;
  }

  /// Emit error event
  void _emitError(ConnectionErrorType type, String message) {
    _errorController.add(ConnectionError(type: type, message: message));
  }

  /// Log message (only in debug mode)
  void _log(String message, {bool isError = false}) {
    if (EnvConfig.enableLogging) {
      if (isError) {
        debugPrint(' [ConnectivityManager] $message');
      } else {
        debugPrint('[Connectivity] $message');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _log('Disposing ConnectivityManager');
    _subscription?.cancel();
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _stateController.close();
    _typeController.close();
    _errorController.close();
  }
}

/// Connection error types
enum ConnectionErrorType {
  streamError,
  checkFailed,
  verificationFailed,
  connectionLost,
  maxRetriesReached,
  timeout,
  unknown,
}

/// Connection error details
class ConnectionError {
  final ConnectionErrorType type;
  final String message;
  final DateTime timestamp;

  ConnectionError({
    required this.type,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'ConnectionError(${type.name}): $message';
}

/// Extension for convenient connection checks
extension ConnectivityManagerExtension on ConnectivityManager {
  /// Wait until connected with timeout
  Future<bool> waitForConnection({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (isConnected) return true;

    final completer = Completer<bool>();
    final subscription = stateStream.listen((state) {
      if (state == NetConnectionState.connected) {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      } else if (state == NetConnectionState.unavailable) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      }
    });

    // Check timeout
    Future.delayed(timeout).then((_) {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.complete(false);
      }
    });

    final result = await completer.future;
    subscription.cancel();
    return result;
  }

  /// Execute action only if connected
  Future<T?> executeIfConnected<T>(Future<T> Function() action) async {
    if (!isConnected) return null;
    try {
      return await action();
    } catch (e) {
      return null;
    }
  }

  /// Execute action with automatic retry on connection failure
  Future<T?> executeWithRetry<T>(
    Future<T> Function() action, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        // Wait for connection if needed
        if (!isConnected) {
          final connected = await waitForConnection();
          if (!connected) {
            attempts++;
            if (attempts < maxRetries) {
              await Future.delayed(retryDelay);
              continue;
            }
            return null;
          }
        }
        
        // Execute action
        return await action();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) return null;
        await Future.delayed(retryDelay);
      }
    }
    
    return null;
  }
}

/// Connection state change event
class ConnectionStateChange {
  final NetConnectionState previousState;
  final NetConnectionState currentState;
  final DateTime timestamp;

  ConnectionStateChange({
    required this.previousState,
    required this.currentState,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'ConnectionStateChange: $previousState -> $currentState';
}
