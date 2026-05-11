import 'dart:convert';

import 'raw_api_request.dart';

class EventsApiClient {
  final RawApiRequest _rawRequest;

  const EventsApiClient(this._rawRequest);

  Future<List<Map<String, dynamic>>> getEvents() async {
    final response = await _rawRequest('/api/events', method: 'GET');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    final response = await _rawRequest('/api/announcements', method: 'GET');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    }
    return [];
  }

  Future<Map<String, dynamic>?> rsvpEvent(int eventId) async {
    final response = await _rawRequest(
      '/api/events/$eventId/rsvp',
      method: 'POST',
      body: {'status': 'going'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> createEvent(Map<String, dynamic> data) async {
    final response = await _rawRequest(
      '/api/events/create',
      method: 'POST',
      body: data,
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    return null;
  }
}
