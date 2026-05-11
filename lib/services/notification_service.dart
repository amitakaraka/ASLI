import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _setupToken();
        await _setupHandlers();
      }

      _initialized = true;
    } catch (e) {
      debugPrint('FCM init error: $e');
    }
  }

  Future<void> _setupToken() async {
    final token = await _fcm.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');
      await _sendTokenToServer(token);
    }

    _fcm.onTokenRefresh.listen(_sendTokenToServer);
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      await ApiService.updateFcmToken(token);
    } catch (e) {
      debugPrint('Failed to send FCM token: $e');
    }
  }

  Future<void> _setupHandlers() async {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');

    final data = message.data;
    _showLocalNotification(
      title: message.notification?.title ?? 'New Notification',
      body: message.notification?.body ?? '',
      payload: jsonEncode(data),
    );
  }

  void _handleMessageOpened(RemoteMessage message) {
    debugPrint('Message opened: ${message.data}');
    final data = message.data;
    _handleNotificationTap(data);
  }

  void _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) {}

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    // Handle navigation based on notification type
    switch (type) {
      case 'message':
      case 'dm':
      case 'notification':
        break;
      case 'post':
        break;
      case 'event':
        break;
      default:
        break;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
    debugPrint('Subscribed to: $topic');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from: $topic');
  }

  Future<void> subscribeUserChannels(int userId) async {
    await subscribeToTopic('user_$userId');
    await subscribeToTopic('campus_general');
    await subscribeToTopic('events');
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.messageId}');
}
