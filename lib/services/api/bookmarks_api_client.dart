import 'dart:convert';

import 'raw_api_request.dart';

class BookmarksApiClient {
  final RawApiRequest _rawRequest;

  const BookmarksApiClient(this._rawRequest);

  Future<List<dynamic>> getBookmarks() async {
    final response = await _rawRequest('/api/bookmarks/', method: 'GET');
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'] ?? [];
    }
    return [];
  }

  Future<Map<String, dynamic>?> toggleBookmark(int postId) async {
    final response = await _rawRequest(
      '/api/bookmarks/toggle',
      method: 'POST',
      body: {'post_id': postId},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<bool> checkBookmark(int postId) async {
    final response = await _rawRequest(
      '/api/bookmarks/check/$postId',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['bookmarked'] ?? false;
    }
    return false;
  }

  Future<int> getBookmarkCount() async {
    final response = await _rawRequest('/api/bookmarks/count', method: 'GET');
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['count'] ?? 0;
    }
    return 0;
  }
}
