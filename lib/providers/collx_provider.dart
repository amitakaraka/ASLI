import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'websocket_provider.dart';

class CollxPost {
  final int id;
  final int userId;
  final String content;
  final String? username;
  final String? userAvatar;
  final int likeCount;
  final int replyCount;
  final bool isLiked;
  final bool isBookmarked;
  final List<String> hashtags;
  final DateTime createdAt;

  CollxPost({
    required this.id,
    required this.userId,
    required this.content,
    this.username,
    this.userAvatar,
    this.likeCount = 0,
    this.replyCount = 0,
    this.isLiked = false,
    this.isBookmarked = false,
    this.hashtags = const [],
    required this.createdAt,
  });

  factory CollxPost.fromJson(Map<String, dynamic> json) {
    return CollxPost(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? json['author_id'] ?? 0,
      content: json['content'] ?? json['text'] ?? '',
      username: json['username'],
      userAvatar: json['avatar'],
      likeCount: json['like_count'] ?? 0,
      replyCount: json['reply_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      isBookmarked: json['is_bookmarked'] ?? false,
      hashtags:
          (json['hashtags'] as String?)
              ?.split(',')
              .where((h) => h.isNotEmpty)
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class CollxState {
  final List<CollxPost> posts;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;

  const CollxState({
    this.posts = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.error,
  });

  CollxState copyWith({
    List<CollxPost>? posts,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return CollxState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

class CollxNotifier extends StateNotifier<CollxState> {
  final WebSocketNotifier? _ws;

  CollxNotifier(this._ws) : super(const CollxState()) {
    _setupWebSocketListeners();
    loadFeed();
  }

  void _setupWebSocketListeners() {
    if (_ws == null) return;
  }

  Future<void> loadFeed({bool refresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      currentPage: refresh ? 1 : state.currentPage,
      posts: refresh ? [] : state.posts,
    );

    try {
      final data = await ApiService.getCollxFeed(page: state.currentPage);
      final posts = (data as List).map((p) => CollxPost.fromJson(p)).toList();

      state = state.copyWith(
        posts: refresh ? posts : [...state.posts, ...posts],
        isLoading: false,
        hasMore: posts.length >= 10,
        currentPage: state.currentPage + 1,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadFeed(refresh: true);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    await loadFeed();
  }

  Future<void> toggleLike(int postId) async {
    final index = state.posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = state.posts[index];
    final newPosts = List<CollxPost>.from(state.posts);
    newPosts[index] = CollxPost(
      id: post.id,
      userId: post.userId,
      content: post.content,
      username: post.username,
      userAvatar: post.userAvatar,
      likeCount: post.isLiked ? post.likeCount - 1 : post.likeCount + 1,
      replyCount: post.replyCount,
      isLiked: !post.isLiked,
      isBookmarked: post.isBookmarked,
      hashtags: post.hashtags,
      createdAt: post.createdAt,
    );

    state = state.copyWith(posts: newPosts);

    try {
      await ApiService.toggleCollxLike(postId);
    } catch (e) {
      newPosts[index] = post;
      state = state.copyWith(posts: newPosts);
    }
  }

  Future<void> toggleBookmark(int postId) async {
    final index = state.posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = state.posts[index];
    final newPosts = List<CollxPost>.from(state.posts);
    newPosts[index] = CollxPost(
      id: post.id,
      userId: post.userId,
      content: post.content,
      username: post.username,
      userAvatar: post.userAvatar,
      likeCount: post.likeCount,
      replyCount: post.replyCount,
      isLiked: post.isLiked,
      isBookmarked: !post.isBookmarked,
      hashtags: post.hashtags,
      createdAt: post.createdAt,
    );

    state = state.copyWith(posts: newPosts);

    try {
      await ApiService.toggleBookmark(postId);
    } catch (e) {
      newPosts[index] = post;
      state = state.copyWith(posts: newPosts);
    }
  }

  void addNewPost(Map<String, dynamic> postData) {
    final newPost = CollxPost.fromJson(postData);
    state = state.copyWith(posts: [newPost, ...state.posts]);
  }

  void handleNewPostNotification(Map<String, dynamic> data) {
    addNewPost(data);
  }
}

final collxProvider = StateNotifierProvider<CollxNotifier, CollxState>((ref) {
  final ws = ref.watch(webSocketProvider.notifier);
  return CollxNotifier(ws);
});

final collxPostsProvider = Provider<List<CollxPost>>((ref) {
  return ref.watch(collxProvider).posts;
});

final isCollxLoadingProvider = Provider<bool>((ref) {
  return ref.watch(collxProvider).isLoading;
});
