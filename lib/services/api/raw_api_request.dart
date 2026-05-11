import 'package:http/http.dart' as http;

typedef RawApiRequest = Future<http.Response> Function(
  String url, {
  required String method,
  Map<String, String>? headers,
  Object? body,
  Duration? timeout,
});
