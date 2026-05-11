import 'dart:convert';

import 'raw_api_request.dart';

class QaApiClient {
  final RawApiRequest _rawRequest;

  const QaApiClient(this._rawRequest);

  Future<List<Map<String, dynamic>>> getQuestions({int limit = 20}) async {
    final response = await _rawRequest(
      '/api/questions?limit=$limit',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(
        jsonDecode(response.body)['data'] ?? [],
      );
    }
    return [];
  }

  Future<Map<String, dynamic>?> addQuestion(
    String content, [
    String? details,
  ]) async {
    final body = {'content': content};
    if (details != null && details.isNotEmpty) body['details'] = details;
    final response = await _rawRequest(
      '/api/questions',
      method: 'POST',
      body: body,
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAnswers(int questionId) async {
    final response = await _rawRequest(
      '/api/questions/$questionId/answers',
      method: 'GET',
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(
        jsonDecode(response.body)['data'] ?? [],
      );
    }
    return [];
  }

  Future<bool> addAnswer(int questionId, String text) async {
    final response = await _rawRequest(
      '/api/qa/$questionId/answers',
      method: 'POST',
      body: {'text': text},
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }
}
