import 'dart:convert';

import 'raw_api_request.dart';

class CollxApiClient {
  final RawApiRequest _rawRequest;

  const CollxApiClient(this._rawRequest);

  Future<List<Map<String, dynamic>>> getFeed({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _rawRequest(
        '/api/collx/feed?page=$page&limit=$limit',
        method: 'GET',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getPost(int postId) async {
    try {
      final response = await _rawRequest(
        '/api/collx/posts/$postId',
        method: 'GET',
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> createPost(
    String content, {
    String? imageUrl,
  }) async {
    try {
      final response = await _rawRequest(
        '/api/collx/posts',
        method: 'POST',
        body: {'content': content, if (imageUrl != null) 'image_url': imageUrl},
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body)['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> toggleLike(int postId) async {
    try {
      final response = await _rawRequest(
        '/api/collx/posts/$postId/like',
        method: 'POST',
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> replyToPost(int postId, String content) async {
    try {
      final response = await _rawRequest(
        '/api/collx/posts/$postId/reply',
        method: 'POST',
        body: {'content': content},
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> repost(int postId) async {
    try {
      final response = await _rawRequest(
        '/api/collx/posts/$postId/repost',
        method: 'POST',
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getTrending() async {
    try {
      final response = await _rawRequest('/api/collx/trending', method: 'GET');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> search(String query) async {
    try {
      final response = await _rawRequest(
        '/api/collx/search?q=$query',
        method: 'GET',
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUser(int userId) async {
    try {
      final response = await _rawRequest('/api/users/$userId', method: 'GET');
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['user'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> toggleFollow(int userId) async {
    try {
      final response = await _rawRequest(
        '/api/users/$userId/follow',
        method: 'POST',
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
