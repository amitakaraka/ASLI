import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/providers/collx_provider.dart';

void main() {
  group('CollxState', () {
    test('initial state has correct defaults', () {
      const state = CollxState();

      expect(state.posts, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.hasMore, isTrue);
      expect(state.currentPage, 1);
      expect(state.error, isNull);
    });

    test('copyWith creates new instance with updated values', () {
      const original = CollxState();
      final updated = original.copyWith(isLoading: true, currentPage: 2);

      expect(updated.isLoading, isTrue);
      expect(updated.currentPage, 2);
      expect(original.isLoading, isFalse);
    });
  });

  group('CollxPost', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 1,
        'user_id': 5,
        'content': 'Test post content',
        'username': 'testuser',
        'like_count': 10,
        'reply_count': 5,
        'is_liked': true,
        'hashtags': '#test,#flutter',
        'created_at': '2026-03-18T10:00:00Z',
      };

      final post = CollxPost.fromJson(json);

      expect(post.id, 1);
      expect(post.userId, 5);
      expect(post.content, 'Test post content');
      expect(post.username, 'testuser');
      expect(post.likeCount, 10);
      expect(post.replyCount, 5);
      expect(post.isLiked, true);
      expect(post.hashtags, ['#test', '#flutter']);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 1,
        'user_id': 5,
        'content': 'Test content',
        'created_at': '2026-03-18T10:00:00Z',
      };

      final post = CollxPost.fromJson(json);

      expect(post.id, 1);
      expect(post.username, isNull);
      expect(post.likeCount, 0);
      expect(post.isLiked, false);
    });
  });

  group('Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('collxProvider returns initial state', () {
      final state = container.read(collxProvider);

      expect(state.posts, isEmpty);
      expect(state.isLoading, isTrue);
    });

    test('collxPostsProvider returns empty list initially', () {
      final posts = container.read(collxPostsProvider);

      expect(posts, isEmpty);
    });

    test('isCollxLoadingProvider returns false initially', () {
      final isLoading = container.read(isCollxLoadingProvider);

      expect(isLoading, isTrue);
    });
  });
}
