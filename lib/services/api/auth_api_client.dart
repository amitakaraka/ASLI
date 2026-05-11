import 'dart:convert';

import 'raw_api_request.dart';

class AuthApiClient {
  final RawApiRequest _rawRequest;

  const AuthApiClient(this._rawRequest);

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String username,
    String department = '',
    String year = '',
  }) async {
    final response = await _rawRequest(
      '/api/auth/register',
      method: 'POST',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'username': username,
        'department': department,
        'year': year,
      },
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final response = await _rawRequest(
      '/api/auth/login',
      method: 'POST',
      body: {'email': identifier, 'password': password},
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>?> getMe() async {
    final response = await _rawRequest('/api/auth/me', method: 'GET');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> updateProfile(Map<String, dynamic> body) async {
    final response = await _rawRequest(
      '/api/auth/me',
      method: 'PUT',
      body: body,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }
}
