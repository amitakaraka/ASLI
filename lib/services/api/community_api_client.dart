import 'dart:convert';

import 'raw_api_request.dart';

class CommunityApiClient {
  final RawApiRequest _rawRequest;

  const CommunityApiClient(this._rawRequest);

  Future<Map<String, dynamic>?> getCommunityPosts({String? channel}) async {
    final url = channel != null ? '/api/community/$channel' : '/api/community/';
    final response = await _rawRequest(url, method: 'GET');
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) return body;
      if (body is List) return {'posts': body};
    }
    return null;
  }

  Future<List<dynamic>?> getCommunityChannels() async {
    final response = await _rawRequest('/api/community/', method: 'GET');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> createCommunityPost(
    String content, {
    String channel = 'general',
  }) async {
    final response = await _rawRequest(
      '/api/community/create',
      method: 'POST',
      body: {'content': content, 'channel': channel},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> postToCommunity(
    String channelId,
    String content,
  ) {
    return createCommunityPost(content, channel: channelId);
  }
}
