import 'dart:convert';

import 'raw_api_request.dart';

class StoriesApiClient {
  final RawApiRequest _rawRequest;

  const StoriesApiClient(this._rawRequest);

  Future<List<dynamic>?> getStories() async {
    final response = await _rawRequest('/api/stories/', method: 'GET');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> createStory(
    String text,
    String bgColor, {
    String emoji = '',
  }) async {
    final response = await _rawRequest(
      '/api/stories/create',
      method: 'POST',
      body: {'text': text, 'bg_color': bgColor, 'emoji': emoji},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<void> viewStory(int storyId) async {
    await _rawRequest('/api/stories/view/$storyId', method: 'POST');
  }
}
