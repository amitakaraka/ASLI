import 'dart:convert';

import 'raw_api_request.dart';

class ChatApiClient {
  final RawApiRequest _rawRequest;

  const ChatApiClient(this._rawRequest);

  Future<Map<String, dynamic>?> sendLegacyMessage(String message) async {
    try {
      final response = await _rawRequest(
        '/api/chat',
        method: 'POST',
        body: {'message': message, 'save_question': true},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> sendMessage(
    String message, {
    String? conversationId,
  }) async {
    try {
      final response = await _rawRequest(
        '/api/chat/message',
        method: 'POST',
        body: {
          'message': message,
          'conversation_id': conversationId,
          'save': true,
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> getSuggestions(String prefix) async {
    try {
      final response = await _rawRequest(
        '/api/chat/suggestions?q=$prefix',
        method: 'GET',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['suggestions'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getHistory({
    int page = 1,
    String? sessionId,
  }) async {
    try {
      var url = '/api/chat/history?page=$page';
      if (sessionId != null) {
        url += '&session_id=$sessionId';
      }
      final response = await _rawRequest(url, method: 'GET');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> clearHistory({String? sessionId}) async {
    try {
      final response = await _rawRequest(
        '/api/chat/clear-history',
        method: 'POST',
        body: sessionId != null ? {'session_id': sessionId} : null,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getStats() async {
    try {
      final response = await _rawRequest('/api/chat/stats', method: 'GET');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['stats'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
