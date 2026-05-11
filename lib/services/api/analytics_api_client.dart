import 'dart:convert';

import 'raw_api_request.dart';

class AnalyticsApiClient {
  final RawApiRequest _rawRequest;

  const AnalyticsApiClient(this._rawRequest);

  Future<Map<String, dynamic>?> getStats() async {
    final response = await _rawRequest('/api/analytics/stats', method: 'GET');
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    }
    return null;
  }

  Future<List<dynamic>> getActivityFeed() async {
    final response = await _rawRequest(
      '/api/analytics/activity',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'] ?? [];
    }
    return [];
  }

  Future<List<dynamic>> getLeaderboard() async {
    final response = await _rawRequest(
      '/api/analytics/leaderboard',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'] ?? [];
    }
    return [];
  }

  Future<List<dynamic>> getModuleHealth() async {
    final response = await _rawRequest('/api/analytics/health', method: 'GET');
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['modules'] ?? [];
    }
    return [];
  }

  Future<Map<String, dynamic>?> getEngagementLeaderboard() async {
    final response = await _rawRequest(
      '/api/leaderboard/engagement',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) return body;
      if (body is List) return {'leaderboard': body};
    }
    return null;
  }
}
