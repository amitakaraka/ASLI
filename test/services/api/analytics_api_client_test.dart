import 'package:asli_app/services/api/analytics_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('AnalyticsApiClient', () {
    test('parses stats data payload', () async {
      final client = AnalyticsApiClient((
        url, {
        required String method,
        Map<String, String>? headers,
        Object? body,
        Duration? timeout,
      }) {
        expect(url, '/api/analytics/stats');
        expect(method, 'GET');
        return Future.value(
          http.Response(
            '{"data":{"users":12,"posts":34}}',
            200,
            headers: {'content-type': 'application/json'},
          ),
        );
      });

      final stats = await client.getStats();

      expect(stats, {'users': 12, 'posts': 34});
    });

    test('returns empty activity feed on non-200 responses', () async {
      final client = AnalyticsApiClient(
        (
          url, {
          required String method,
          Map<String, String>? headers,
          Object? body,
          Duration? timeout,
        }) => Future.value(http.Response('{"error":"nope"}', 500)),
      );

      expect(await client.getActivityFeed(), isEmpty);
    });

    test('normalizes list engagement leaderboard responses', () async {
      final client = AnalyticsApiClient((
        url, {
        required String method,
        Map<String, String>? headers,
        Object? body,
        Duration? timeout,
      }) {
        expect(url, '/api/leaderboard/engagement');
        return Future.value(http.Response('[{"user":"arya","score":9}]', 200));
      });

      expect(await client.getEngagementLeaderboard(), {
        'leaderboard': [
          {'user': 'arya', 'score': 9},
        ],
      });
    });
  });
}
