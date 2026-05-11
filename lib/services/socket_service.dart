import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/env_config.dart';
import 'connectivity_manager.dart';

/// Socket connection state
enum SocketConnectionState {
  disconnected,
  connecting,
  connected,
  authenticated,
  error,
  reconnected,
}

/// Socket event types
enum SocketEvent {
  connected,
  disconnected,
  error,
  newMessage,
  typing,
  readReceipt,
  notification,
  messageSent,
  authenticated,
  reconnected,
}

/// Socket message model
class SocketMessage {
  final String? from;
  final String? to;
  final String? content;
  final String? conversationId;
  final DateTime? timestamp;
  final Map<String, dynamic>? data;

  SocketMessage({
    this.from,
    this.to,
    this.content,
    this.conversationId,
    this.timestamp,
    this.data,
  });

  factory SocketMessage.fromJson(Map<String, dynamic> json) {
    return SocketMessage(
      from: json['from']?.toString(),
      to: json['to']?.toString(),
      content: json['content']?.toString(),
      conversationId: json['conversation_id']?.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'])
          : null,
      data: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (content != null) 'content': content,
      if (conversationId != null) 'conversation_id': conversationId,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      if (data != null) ...data!,
    };
  }
}

/// Socket typing indicator model
class SocketTyping {
  final String? conversationId;
  final String? fromUser;
  final bool isTyping;

  SocketTyping({this.conversationId, this.fromUser, required this.isTyping});

  factory SocketTyping.fromJson(Map<String, dynamic> json) {
    return SocketTyping(
      conversationId: json['conversation_id']?.toString(),
      fromUser: json['from_user']?.toString(),
      isTyping: json['is_typing'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (conversationId != null) 'conversation_id': conversationId,
      if (fromUser != null) 'from_user': fromUser,
      'is_typing': isTyping,
    };
  }
}

/// Socket error model
class SocketError {
  final String message;
  final String? code;
  final DateTime timestamp;

  SocketError({
    required this.message,
    this.code,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'SocketError: $message${code != null ? ' ($code)' : ''}';
}

/// Socket service for real-time communication
class SocketService {
  static SocketService? _instance;
  static SocketService get instance => _instance ??= SocketService._();

  SocketService._();

  io.Socket? _socket;
  SocketConnectionState _state = SocketConnectionState.disconnected;
  bool _isAuthenticated = false;
  int? _currentUserId;
  String? _currentRoom;

  // Stream controllers
  final _stateController = StreamController<SocketConnectionState>.broadcast();
  final _messageController = StreamController<SocketMessage>.broadcast();
  final _typingController = StreamController<SocketTyping>.broadcast();
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<SocketError>.broadcast();
  final _reconnectController = StreamController<int>.broadcast();

  // Reconnection tracking
  int _reconnectAttempts = 0;
  DateTime? _lastConnectedAt;
  DateTime? _lastDisconnectedAt;
  final _pendingMessages = <Map<String, dynamic>>[];

  // Streams
  Stream<SocketConnectionState> get stateStream => _stateController.stream;
  Stream<SocketMessage> get messageStream => _messageController.stream;
  Stream<SocketTyping> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;
  Stream<SocketError> get errorStream => _errorController.stream;
  Stream<int> get reconnectStream => _reconnectController.stream;

  // State getters
  SocketConnectionState get state => _state;
  bool get isConnected => _state == SocketConnectionState.connected || _state == SocketConnectionState.authenticated;
  bool get isConnecting => _state == SocketConnectionState.connecting;
  bool get isDisconnected => _state == SocketConnectionState.disconnected;
  bool get isAuthenticated => _isAuthenticated;
  int? get currentUserId => _currentUserId;
  DateTime? get lastConnectedAt => _lastConnectedAt;
  DateTime? get lastDisconnectedAt => _lastDisconnectedAt;
  bool get hasPendingMessages => _pendingMessages.isNotEmpty;

  /// Connect to Socket.IO server
  Future<void> connect() async {
    if (_socket != null && isConnected) {
      _log('Socket already connected');
      return;
    }

    // Check network connectivity first
    if (!ConnectivityManager.instance.isConnected) {
      _log('No network connection. Cannot connect socket.', isError: true);
      _updateState(SocketConnectionState.disconnected);
      return;
    }

    _log('Connecting to ${EnvConfig.wsUrl}...');
    _updateState(SocketConnectionState.connecting);

    try {
      _socket = io.io(
        EnvConfig.wsUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setExtraHeaders({
              'Bypass-Tunnel-Reminder': 'true',
              'ngrok-skip-browser-warning': 'true',
            })
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(EnvConfig.socketReconnectAttempts)
            .setReconnectionDelay(EnvConfig.socketReconnectDelay.inMilliseconds)
            .setReconnectionDelayMax(EnvConfig.socketReconnectDelayMax.inMilliseconds)
            .setTimeout(EnvConfig.socketTimeout.inMilliseconds)
            .enableMultiplex()
            .build(),
      );

      _setupListeners();
      _socket!.connect();
    } catch (e) {
      _log('Failed to create socket: $e', isError: true);
      _emitError(SocketError(message: 'Failed to create socket: $e'));
      _updateState(SocketConnectionState.error);
    }
  }

  /// Setup socket event listeners
  void _setupListeners() {
    if (_socket == null) return;

    // Connection events
    _socket!.onConnect((_) {
      _log('Socket connected');
      _state = SocketConnectionState.connected;
      _lastConnectedAt = DateTime.now();
      _lastDisconnectedAt = null;
      _reconnectAttempts = 0;
      _stateController.add(SocketConnectionState.connected);
      
      // Re-authenticate if we have a user ID
      if (_currentUserId != null) {
        authenticate(_currentUserId!);
      }

      // Send any pending messages
      _flushPendingMessages();
    });

    _socket!.onDisconnect((data) {
      _log('Socket disconnected: $data');
      _state = SocketConnectionState.disconnected;
      _lastDisconnectedAt = DateTime.now();
      _isAuthenticated = false;
      _stateController.add(SocketConnectionState.disconnected);
    });

    _socket!.onConnectError((error) {
      _log('Connection error: $error', isError: true);
      _state = SocketConnectionState.error;
      _emitError(SocketError(message: 'Connection error: $error'));
      _stateController.add(SocketConnectionState.error);
    });

    _socket!.onError((error) {
      _log('Socket error: $error', isError: true);
      _emitError(SocketError(message: 'Socket error: $error'));
    });

    _socket!.onReconnect((data) {
      _reconnectAttempts++;
      _log('Socket reconnected (attempt $_reconnectAttempts)');
      _reconnectController.add(_reconnectAttempts);
      _stateController.add(SocketConnectionState.reconnected);
    });

    _socket!.onReconnectError((error) {
      _log('Reconnection error: $error', isError: true);
      _emitError(SocketError(message: 'Reconnection error: $error'));
    });

    // Authentication events
    _socket!.on('authenticated', (data) {
      _log('Socket authenticated: $data');
      _isAuthenticated = true;
      _state = SocketConnectionState.authenticated;
      _stateController.add(SocketConnectionState.authenticated);
    });

    _socket!.on('auth_error', (data) {
      _log('Authentication error: $data', isError: true);
      _isAuthenticated = false;
      _emitError(SocketError(message: data['message'] ?? 'Authentication failed'));
    });

    // Error events
    _socket!.on('error', (data) {
      _log('Server error: $data', isError: true);
      _emitError(SocketError(message: data['message'] ?? 'Unknown error'));
    });

    // Message events
    _socket!.on('new_message', (data) {
      if (data != null) {
        final msg = SocketMessage.fromJson(Map<String, dynamic>.from(data));
        _log('New message received from ${msg.from}');
        _messageController.add(msg);
      }
    });

    _socket!.on('message_sent', (data) {
      if (data != null) {
        final msg = SocketMessage.fromJson(Map<String, dynamic>.from(data));
        _log('Message sent confirmation: ${msg.conversationId}');
        _messageController.add(msg);
      }
    });

    // Typing events
    _socket!.on('typing', (data) {
      if (data != null) {
        final typing = SocketTyping.fromJson(Map<String, dynamic>.from(data));
        _typingController.add(typing);
      }
    });

    // Read receipt events
    _socket!.on('read_receipt', (data) {
      _log('Read receipt: $data');
    });

    // Notification events
    _socket!.on('notification', (data) {
      if (data != null) {
        _log('Notification received: ${data['type']}');
        _notificationController.add(Map<String, dynamic>.from(data));
      }
    });

    // Pong events (heartbeat)
    _socket!.on('pong', (data) {
      _log('Pong received: $data');
    });
  }

  /// Authenticate socket connection
  void authenticate(int userId) {
    _currentUserId = userId;
    _log('Authenticating socket for user $userId');
    _socket?.emit('authenticate', {'user_id': userId});
  }

  /// Join a room
  void joinRoom(String room) {
    if (!isConnected) {
      _log('Cannot join room - not connected', isError: true);
      return;
    }
    _currentRoom = room;
    _log('Joining room: $room');
    _socket?.emit('join', {'room': room});
  }

  /// Leave a room
  void leaveRoom(String room) {
    _log('Leaving room: $room');
    _socket?.emit('leave', {'room': room});
    if (_currentRoom == room) {
      _currentRoom = null;
    }
  }

  /// Send private message
  void sendPrivateMessage({
    required int toUserId,
    required String content,
    String? conversationId,
  }) {
    if (!isConnected) {
      _log('Cannot send message - not connected. Queuing message.', isError: true);
      _queueMessage({
        'to': toUserId,
        'content': content,
        'conversation_id': conversationId,
      });
      return;
    }

    _log('Sending private message to user $toUserId');
    _socket?.emit('private_message', {
      'to': toUserId,
      'content': content,
      'conversation_id': conversationId,
    });
  }

  /// Send typing indicator
  void sendTyping({
    required int toUserId,
    String? conversationId,
    required bool isTyping,
  }) {
    if (!isConnected) return;
    
    _socket?.emit('typing', {
      'to_user': toUserId,
      'conversation_id': conversationId,
      'is_typing': isTyping,
    });
  }

  /// Mark messages as read
  void markAsRead({required int toUserId, required String conversationId}) {
    if (!isConnected) return;
    
    _socket?.emit('mark_read', {
      'to_user': toUserId,
      'conversation_id': conversationId,
    });
  }

  /// Subscribe to notifications
  void subscribeToNotifications(int userId) {
    if (!isConnected) return;
    
    _log('Subscribing to notifications for user $userId');
    _socket?.emit('notification_subscribe', {'user_id': userId});
  }

  /// Send ping (heartbeat)
  void ping() {
    if (!isConnected) return;
    _socket?.emit('ping');
  }

  /// Emit custom event
  void emit(String event, [dynamic data]) {
    if (!isConnected) {
      _log('Cannot emit $event - not connected', isError: true);
      return;
    }
    _socket?.emit(event, data);
  }

  /// Listen to custom event
  void on(String event, Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  /// Remove listener
  void off(String event, [Function(dynamic)? callback]) {
    _socket?.off(event, callback);
  }

  /// Queue message for later delivery
  void _queueMessage(Map<String, dynamic> message) {
    _pendingMessages.add(message);
    _log('Message queued. Total pending: ${_pendingMessages.length}');
  }

  /// Flush pending messages
  void _flushPendingMessages() {
    if (_pendingMessages.isEmpty) return;

    _log('Flushing ${_pendingMessages.length} pending messages');
    
    final messages = List<Map<String, dynamic>>.from(_pendingMessages);
    _pendingMessages.clear();

    for (final message in messages) {
      if (message.containsKey('to') && message.containsKey('content')) {
        _socket?.emit('private_message', message);
      }
    }
  }

  /// Update connection state
  void _updateState(SocketConnectionState state) {
    if (_state == state) return;
    _state = state;
    _stateController.add(state);
  }

  /// Emit error
  void _emitError(SocketError error) {
    _errorController.add(error);
  }

  /// Log message (debug mode only)
  void _log(String message, {bool isError = false}) {
    if (EnvConfig.enableLogging) {
      if (isError) {
        debugPrint(' [SocketService] $message');
      } else {
        debugPrint('🔌 [SocketService] $message');
      }
    }
  }

  /// Disconnect from server
  void disconnect() {
    _log('Disconnecting socket...');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _state = SocketConnectionState.disconnected;
    _isAuthenticated = false;
    _currentRoom = null;
  }

  /// Dispose resources
  void dispose() {
    _log('Disposing SocketService');
    disconnect();
    _stateController.close();
    _messageController.close();
    _typingController.close();
    _notificationController.close();
    _errorController.close();
    _reconnectController.close();
  }

  /// Get connection statistics
  Map<String, dynamic> getStats() {
    return {
      'state': _state.name,
      'isConnected': isConnected,
      'isAuthenticated': _isAuthenticated,
      'currentUserId': _currentUserId,
      'currentRoom': _currentRoom,
      'reconnectAttempts': _reconnectAttempts,
      'pendingMessages': _pendingMessages.length,
      'lastConnectedAt': _lastConnectedAt?.toIso8601String(),
      'lastDisconnectedAt': _lastDisconnectedAt?.toIso8601String(),
    };
  }
}

/// Extension for convenient socket operations
extension SocketServiceExtension on SocketService {
  /// Wait for socket to be connected
  Future<bool> waitForConnection({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (isConnected) return true;

    final completer = Completer<bool>();
    final subscription = stateStream.listen((state) {
      if (state == SocketConnectionState.connected || 
          state == SocketConnectionState.authenticated) {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      } else if (state == SocketConnectionState.error) {
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

  /// Execute action only if socket is authenticated
  Future<T?> executeIfAuthenticated<T>(Future<T> Function() action) async {
    if (!isAuthenticated) return null;
    try {
      return await action();
    } catch (e) {
      return null;
    }
  }
}
