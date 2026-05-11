import 'dart:convert';

import 'raw_api_request.dart';

class StudyGroupsApiClient {
  final RawApiRequest _rawRequest;

  const StudyGroupsApiClient(this._rawRequest);

  Future<List<dynamic>?> getStudyGroups() async {
    final response = await _rawRequest('/api/studygroups/', method: 'GET');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> createStudyGroup(
    String name,
    String subject, {
    String description = '',
    String emoji = '📚',
    String color = '#3B82F6',
  }) async {
    final response = await _rawRequest(
      '/api/studygroups/create',
      method: 'POST',
      body: {
        'name': name,
        'subject': subject,
        'description': description,
        'emoji': emoji,
        'color': color,
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> joinStudyGroup(int groupId) async {
    final response = await _rawRequest(
      '/api/studygroups/join/$groupId',
      method: 'POST',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> leaveStudyGroup(int groupId) async {
    final response = await _rawRequest(
      '/api/studygroups/leave/$groupId',
      method: 'POST',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> getStudyGroupDetail(int groupId) async {
    final response = await _rawRequest(
      '/api/studygroups/$groupId',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<List<dynamic>?> getMyStudyGroups() async {
    final response = await _rawRequest('/api/studygroups/my', method: 'GET');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> getGroupMessages(int groupId) async {
    final response = await _rawRequest(
      '/api/studygroups/$groupId/messages',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> sendGroupMessage(
    int groupId,
    String content,
  ) async {
    final response = await _rawRequest(
      '/api/studygroups/$groupId/send',
      method: 'POST',
      body: {'content': content},
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    return null;
  }
}
