import 'dart:convert';

import 'raw_api_request.dart';

class NotificationsApiClient {
  final RawApiRequest _rawRequest;

  const NotificationsApiClient(this._rawRequest);

  Future<Map<String, dynamic>?> getNotifications() async {
    final response = await _rawRequest('/api/notifications', method: 'GET');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<int> getUnreadCount() async {
    final response = await _rawRequest(
      '/api/notifications/unread-count',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['count'] ?? 0;
    }
    return 0;
  }

  Future<void> markAllRead() async {
    await _rawRequest('/api/notifications/read-all', method: 'POST');
  }

  Future<bool> markRead(int id) async {
    final response = await _rawRequest(
      '/api/notifications/$id/read',
      method: 'POST',
    );
    return response.statusCode == 200;
  }

  Future<void> updateFcmToken(String token) async {
    await _rawRequest(
      '/api/users/fcm-token',
      method: 'POST',
      body: {'token': token},
    );
  }
}
