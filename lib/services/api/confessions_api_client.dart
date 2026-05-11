import 'dart:convert';

import 'raw_api_request.dart';

class ConfessionsApiClient {
  final RawApiRequest _rawRequest;

  const ConfessionsApiClient(this._rawRequest);

  Future<Map<String, dynamic>?> getConfessions({String? category}) async {
    final url = category != null
        ? '/api/confessions/?category=$category'
        : '/api/confessions/';
    final response = await _rawRequest(url, method: 'GET');
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) return body;
      if (body is List) {
        return {'confessions': body, 'categories': [], 'reaction_emojis': []};
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> createConfession(
    String content, {
    String category = 'general',
    String mood = '😶',
  }) async {
    final response = await _rawRequest(
      '/api/confessions/create',
      method: 'POST',
      body: {'content': content, 'category': category, 'mood': mood},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> reactToConfession(
    int confessionId,
    String emoji,
  ) async {
    final response = await _rawRequest(
      '/api/confessions/$confessionId/react',
      method: 'POST',
      body: {'emoji': emoji},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> reactConfession(
    int confessionId,
    String reaction,
  ) async {
    final response = await _rawRequest(
      '/api/confessions/$confessionId/react',
      method: 'POST',
      body: {'reaction': reaction},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }
}
