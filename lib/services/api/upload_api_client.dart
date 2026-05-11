import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../config/env_config.dart';
import '../secure_storage_service.dart';

typedef UploadTokenProvider = Future<String?> Function();
typedef UploadRequestSender =
    Future<http.Response> Function(http.MultipartRequest request);

class UploadApiClient {
  final String? baseUrl;
  final UploadTokenProvider _tokenProvider;
  final UploadRequestSender _sendRequest;

  UploadApiClient({
    this.baseUrl,
    UploadTokenProvider? tokenProvider,
    UploadRequestSender? sendRequest,
  }) : _tokenProvider = tokenProvider ?? SecureStorageService.instance.getToken,
       _sendRequest = sendRequest ?? _defaultSendRequest;

  static Future<http.Response> _defaultSendRequest(
    http.MultipartRequest request,
  ) async {
    final streamedResponse = await request.send().timeout(
      EnvConfig.receiveTimeout,
    );
    return http.Response.fromStream(streamedResponse);
  }

  Future<Map<String, dynamic>?> uploadImage(
    String filePath, {
    String folder = 'posts',
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return {'success': false, 'error': 'File not found'};
    }

    final uri = Uri.parse('${baseUrl ?? EnvConfig.apiUrl}/api/upload/image');
    final token = await _tokenProvider();
    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll({
      'Accept': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
      'ngrok-skip-browser-warning': 'true',
      if (token != null) 'Authorization': 'Bearer $token',
    });
    request.fields['folder'] = folder;
    request.files.add(await http.MultipartFile.fromPath('image', file.path));

    final response = await _sendRequest(request);

    if (response.body.isEmpty) {
      return {
        'success': false,
        'error': 'Upload failed: ${response.statusCode}',
      };
    }

    final body = jsonDecode(response.body);
    if (body is Map<String, dynamic>) return body;
    return {'success': false, 'error': 'Invalid response format'};
  }
}
