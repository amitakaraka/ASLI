import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';

enum WebSocketStatus { disconnected, connecting, connected, error }

class WebSocketState {
  final WebSocketStatus status;
  final List<Map<String, dynamic>> messages;
  final bool isTyping;
  final String? error;

  const WebSocketState({
    this.status = WebSocketStatus.disconnected,
    this.messages = const [],
    this.isTyping = false,
    this.error,
  });

  WebSocketState copyWith({
    WebSocketStatus? status,
    List<Map<String, dynamic>>? messages,
    bool? isTyping,
    String? error,
  }) {
    return WebSocketState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      error: error ?? this.error,
    );
  }
}

class WebSocketNotifier extends StateNotifier<WebSocketState> {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  final String baseUrl;

  WebSocketNotifier({this.baseUrl = 'wss://sterilisable-nonsupposing-anisha.ngrok-free.dev'})
    : super(const WebSocketState());

  Future<void> connect() async {
    if (state.status == WebSocketStatus.connecting) return;

    state = state.copyWith(status: WebSocketStatus.connecting);

    try {
      final token = ApiService.token;
      if (token == null) {
        state = state.copyWith(
          status: WebSocketStatus.error,
          error: 'No auth token available',
        );
        return;
      }

      final uri = Uri.parse('$baseUrl/socket.io/?EIO=4&transport=websocket');
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(_onMessage, onError: _onError, onDone: _onDone);

      _startHeartbeat();
    } catch (e) {
      state = state.copyWith(
        status: WebSocketStatus.error,
        error: e.toString(),
      );
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    if (state.status == WebSocketStatus.disconnected) {
      state = state.copyWith(status: WebSocketStatus.connected);
    }

    try {
      final message = jsonDecode(data.toString());

      if (message['type'] == 'notification') {
        state = state.copyWith(messages: [...state.messages, message]);
      } else if (message['type'] == 'typing') {
        state = state.copyWith(isTyping: message['isTyping'] ?? false);
      }
    } catch (_) {}
  }

  void _onError(dynamic error) {
    state = state.copyWith(
      status: WebSocketStatus.error,
      error: error.toString(),
    );
    _scheduleReconnect();
  }

  void _onDone() {
    state = state.copyWith(status: WebSocketStatus.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      send({'type': 'ping'});
    });
  }

  void send(Map<String, dynamic> data) {
    if (_channel != null && state.status == WebSocketStatus.connected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void sendPrivate(int userId, Map<String, dynamic> message) {
    send({'type': 'private_message', 'to': userId, ...message});
  }

  void sendTyping(int conversationId, bool isTyping) {
    send({
      'type': 'typing',
      'conversation_id': conversationId,
      'isTyping': isTyping,
    });
  }

  void joinRoom(String room) {
    send({'type': 'join', 'room': room});
  }

  void leaveRoom(String room) {
    send({'type': 'leave', 'room': room});
  }

  void clearMessages() {
    state = state.copyWith(messages: []);
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}

final webSocketProvider =
    StateNotifierProvider<WebSocketNotifier, WebSocketState>((ref) {
      return WebSocketNotifier();
    });

final notificationsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(webSocketProvider).messages;
});

final isTypingProvider = Provider<bool>((ref) {
  return ref.watch(webSocketProvider).isTyping;
});
