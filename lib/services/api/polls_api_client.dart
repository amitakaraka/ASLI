import 'dart:convert';

import 'raw_api_request.dart';

class PollsApiClient {
  final RawApiRequest _rawRequest;

  const PollsApiClient(this._rawRequest);

  Future<List<dynamic>?> getPolls() async {
    final response = await _rawRequest('/api/polls/', method: 'GET');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> createPoll(
    String question,
    List<String> options, {
    int durationHours = 24,
  }) async {
    final response = await _rawRequest(
      '/api/polls/create',
      method: 'POST',
      body: {
        'question': question,
        'options': options,
        'duration_hours': durationHours,
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> votePoll(int pollId, int optionId) async {
    final response = await _rawRequest(
      '/api/polls/vote',
      method: 'POST',
      body: {'poll_id': pollId, 'option_id': optionId},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }
}
