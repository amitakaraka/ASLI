import 'dart:io';

import 'package:asli_app/services/api/upload_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('UploadApiClient', () {
    test('returns a structured failure when the file is missing', () async {
      var sent = false;
      final client = UploadApiClient(
        baseUrl: 'https://example.test',
        sendRequest: (_) {
          sent = true;
          return Future.value(http.Response('{}', 200));
        },
      );

      final result = await client.uploadImage('/tmp/asli-missing-image.jpg');

      expect(sent, isFalse);
      expect(result, {'success': false, 'error': 'File not found'});
    });

    test(
      'sends multipart image uploads with auth and folder metadata',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'asli-upload-test',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final image = File('${tempDir.path}/avatar.jpg');
        await image.writeAsBytes([1, 2, 3, 4]);

        http.MultipartRequest? capturedRequest;
        final client = UploadApiClient(
          baseUrl: 'https://example.test',
          tokenProvider: () async => 'test-token',
          sendRequest: (request) {
            capturedRequest = request;
            return Future.value(
              http.Response(
                '{"success":true,"url":"/uploads/avatar.jpg"}',
                200,
              ),
            );
          },
        );

        final result = await client.uploadImage(image.path, folder: 'profiles');

        expect(result, {'success': true, 'url': '/uploads/avatar.jpg'});
        expect(capturedRequest, isNotNull);
        expect(capturedRequest!.method, 'POST');
        expect(
          capturedRequest!.url.toString(),
          'https://example.test/api/upload/image',
        );
        expect(capturedRequest!.headers['Authorization'], 'Bearer test-token');
        expect(capturedRequest!.headers['Accept'], 'application/json');
        expect(capturedRequest!.fields['folder'], 'profiles');
        expect(capturedRequest!.files.single.field, 'image');
        expect(capturedRequest!.files.single.filename, 'avatar.jpg');
      },
    );

    test('returns a useful error for empty upload responses', () async {
      final tempDir = await Directory.systemTemp.createTemp('asli-upload-test');
      addTearDown(() => tempDir.delete(recursive: true));
      final image = File('${tempDir.path}/avatar.jpg');
      await image.writeAsBytes([1, 2, 3, 4]);

      final client = UploadApiClient(
        baseUrl: 'https://example.test',
        sendRequest: (_) => Future.value(http.Response('', 413)),
      );

      expect(await client.uploadImage(image.path), {
        'success': false,
        'error': 'Upload failed: 413',
      });
    });
  });
}
