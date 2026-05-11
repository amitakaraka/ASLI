import 'dart:convert';

import 'raw_api_request.dart';

class MessagesApiClient {
  final RawApiRequest _rawRequest;

  const MessagesApiClient(this._rawRequest);

  Future<List<dynamic>> getConversations() async {
    final response = await _rawRequest(
      '/api/messages/conversations',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'] ?? [];
    }
    return [];
  }

  Future<Map<String, dynamic>?> getChatMessages(int partnerId) async {
    final response = await _rawRequest(
      '/api/messages/chat/$partnerId',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> sendDM(int receiverId, String content) async {
    final response = await _rawRequest(
      '/api/messages/send',
      method: 'POST',
      body: {'receiver_id': receiverId, 'content': content},
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body)['data'];
    }
    return null;
  }

  Future<int> getUnreadCount() async {
    final response = await _rawRequest(
      '/api/messages/unread-total',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['count'] ?? 0;
    }
    return 0;
  }
}
