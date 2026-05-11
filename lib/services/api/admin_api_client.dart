import 'dart:convert';

import 'raw_api_request.dart';

class AdminApiClient {
  final RawApiRequest _rawRequest;

  const AdminApiClient(this._rawRequest);

  Future<List<dynamic>> getUsers() async {
    final response = await _rawRequest('/api/admin/users', method: 'GET');
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'] ?? [];
    }
    return [];
  }

  Future<Map<String, dynamic>?> toggleUserStatus(int targetId) async {
    final response = await _rawRequest(
      '/api/admin/users/$targetId/toggle',
      method: 'POST',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> getOverview() async {
    final response = await _rawRequest('/api/admin/overview', method: 'GET');
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    }
    return null;
  }

  Future<List<dynamic>> getAuditLog() async {
    final response = await _rawRequest('/api/admin/audit-log', method: 'GET');
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'] ?? [];
    }
    return [];
  }

  Future<bool> deletePost(int postId) async {
    final response = await _rawRequest(
      '/api/admin/posts/$postId',
      method: 'DELETE',
    );
    return response.statusCode == 200;
  }
}
