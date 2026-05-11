import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';
import '../widgets/skeleton_loaders.dart';
import '../widgets/error_states.dart';
import 'collx_post_detail_screen.dart';
import 'search_screen.dart';
import '../widgets/story_widgets.dart';

class CollxFeedScreen extends StatefulWidget {
  const CollxFeedScreen({super.key});

  @override
  State<CollxFeedScreen> createState() => _CollxFeedScreenState();
}

class _CollxFeedScreenState extends State<CollxFeedScreen> {
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _trending = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentTab = 0;
  // Track liked/bookmarked state per post
  final Set<int> _likedPostIds = {};
  final Set<int> _bookmarkedPostIds = {};
  // Double-tap heart animation
  int? _heartAnimPostId;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _loadTrending();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _silentRefresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final posts = await ApiService.getCollxFeed();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTrending() async {
    final trending = await ApiService.getCollxTrending();
    if (mounted) setState(() => _trending = trending);
  }

  Future<void> _silentRefresh() async {
    final posts = await ApiService.getCollxFeed();
    if (mounted && posts.length != _posts.length) {
      setState(() => _posts = posts);
    }
  }

  Future<void> _toggleLike(int index, {bool fromDoubleTap = false}) async {
    final post = _posts[index];
    final postId = post['id'] as int;

    // Optimistic UI update
    setState(() {
      if (_likedPostIds.contains(postId)) {
        _likedPostIds.remove(postId);
        _posts[index]['like_count'] = (post['like_count'] ?? 1) - 1;
      } else {
        _likedPostIds.add(postId);
        _posts[index]['like_count'] = (post['like_count'] ?? 0) + 1;
        if (fromDoubleTap) _heartAnimPostId = postId;
      }
    });

    // Clear heart animation
    if (fromDoubleTap) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _heartAnimPostId = null);
      });
    }

    await ApiService.toggleCollxLike(postId);
  }

  Future<void> _toggleBookmark(int postId) async {
    setState(() {
      if (_bookmarkedPostIds.contains(postId)) {
        _bookmarkedPostIds.remove(postId);
      } else {
        _bookmarkedPostIds.add(postId);
      }
    });
    final result = await ApiService.toggleBookmark(postId);
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['bookmarked'] ? 'Post saved!' : 'Bookmark removed',
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: context.accent,
        ),
      );
    }
  }

  Future<void> _repost(int index) async {
    final post = _posts[index];
    final postId = post['id'] as int;
    
    // Show repost dialog
    final shouldRepost = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repost?'),
        content: Text(
          'This will share "${post['content'].substring(0, 50)}${post['content'].length > 50 ? "..." : ""}" to your followers.',
          style: TextStyle(color: context.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Repost', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
    
    if (shouldRepost != true) return;
    
    // Optimistic UI update
    setState(() {
      _posts[index]['repost_count'] = (post['repost_count'] ?? 0) + 1;
    });
    
    // Call API
    final result = await ApiService.repostCollxPost(postId);
    
    if (mounted) {
      if (result != null) {
        setState(() {
          _posts[index]['repost_count'] = result['repost_count'] ?? _posts[index]['repost_count'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Reposted!'),
            duration: const Duration(seconds: 1),
            backgroundColor: context.accent,
          ),
        );
      } else {
        // Revert on error
        setState(() {
          _posts[index]['repost_count'] = (post['repost_count'] ?? 0);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to repost. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sharePost(int index) {
    final post = _posts[index];
    final content = post['content'] ?? '';
    final author = post['author_username'] ?? 'user';
    
    // Share text
    final shareText = 'Check out this post by @$author on ASLI:\n\n"$content"\n\n#ASLI #CollX';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Share Post',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: context.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _parseColor(post['author_color'] ?? '#A9523C'),
                        child: Text(
                          (post['author_name'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post['author_name'] ?? 'Unknown',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '@$author',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Share options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _shareOption(Icons.copy_rounded, 'Copy', () {
                  Clipboard.setData(ClipboardData(text: shareText));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard!'), duration: Duration(seconds: 1)),
                  );
                }),
                _shareOption(Icons.share_rounded, 'More', () {
                  // TODO: Implement native share
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share feature coming soon!')),
                  );
                }),
                _shareOption(Icons.message_rounded, 'DM', () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Send via DM - Coming soon!')),
                  );
                }),
                _shareOption(Icons.open_in_browser_rounded, 'Link', () {
                  // TODO: Generate post link
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link sharing - Coming soon!')),
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _shareOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: context.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: context.accent, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePost() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.surfaceBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: (context.isDark ? Colors.black : AsliColors.heritageBrown)
                  .withAlpha(30),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Create Post",
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: context.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: 280,
              autofocus: true,
              style: TextStyle(color: context.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                hintText: "What's happening in college?",
                hintStyle: TextStyle(color: context.textSecondary),
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                counterStyle: TextStyle(color: context.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isNotEmpty) {
                  await ApiService.createCollxPost(controller.text.trim());
                  if (context.mounted) Navigator.pop(context);
                  _loadFeed();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                "Post",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AsliColors.primaryMaroon;
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            // Stories bar at top of feed
            if (_currentTab == 0) ...[
              const StoryBar(),
              Divider(height: 1, color: context.borderColor),
            ],
            Expanded(
              child: _currentTab == 0 ? _buildFeed() : _buildTrendingView(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePost,
        backgroundColor: context.accent,
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: context.isDark
            ? AsliColors.darkSurface
            : AsliColors.primaryMaroon,
        boxShadow: [
          BoxShadow(
            color: AsliColors.heritageBrown.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                "X",
                style: TextStyle(
                  color: AsliColors.primaryMaroon,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            "CollX",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.search_rounded,
              color: Colors.white70,
              size: 26,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: context.isDark ? AsliColors.darkCard : AsliColors.lightAsh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _currentTab == 0 ? context.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "For You",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _currentTab == 0
                        ? Colors.white
                        : context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _currentTab == 1 ? context.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Trending",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _currentTab == 1
                        ? Colors.white
                        : context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: 5,
        itemBuilder: (context, index) => const PostSkeletonLoader(),
      );
    }

    if (_hasError) {
      return NetworkErrorWidget(onRetry: _loadFeed, message: _errorMessage);
    }

    if (_posts.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.article_outlined,
        title: 'No posts yet',
        subtitle: 'Be the first to share something!',
        iconColor: context.accent,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFeed,
      color: context.accent,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4),
        itemCount: _posts.length,
        itemBuilder: (context, index) => _buildPostCard(_posts[index], index),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, int index) {
    final color = _parseColor(post['author_color'] ?? '#A9523C');
    final postId = post['id'] as int;
    final isLiked = _likedPostIds.contains(postId);
    final isBookmarked = _bookmarkedPostIds.contains(postId);
    final showHeart = _heartAnimPostId == postId;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CollxPostDetailScreen(postId: postId),
          ),
        ).then((_) => _loadFeed());
      },
      onDoubleTap: () {
        if (!isLiked) _toggleLike(index, fromDoubleTap: true);
      },
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
              boxShadow: [
                BoxShadow(
                  color:
                      (context.isDark ? Colors.black : AsliColors.heritageBrown)
                          .withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author Row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: color,
                      child: Text(
                        (post['author_name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post['author_name'] ?? 'Unknown',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            "@${post['author_username'] ?? 'user'} · ${_timeAgo(post['created_at'])}",
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.more_horiz,
                      color: context.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Content
                Text(
                  post['content'] ?? '',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                // Action buttons
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleLike(index),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                            child: Icon(
                              isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              key: ValueKey(isLiked),
                              color: isLiked
                                  ? context.accent
                                  : context.textSecondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${post['like_count'] ?? 0}',
                            style: TextStyle(
                              color: isLiked
                                  ? context.accent
                                  : context.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    _buildActionBtn(
                      Icons.chat_bubble_outline_rounded,
                      '${post['reply_count'] ?? 0}',
                      context.textSecondary,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CollxPostDetailScreen(postId: postId),
                          ),
                        ).then((_) => _loadFeed());
                      },
                    ),
                    const SizedBox(width: 24),
                    _buildActionBtn(
                      Icons.repeat_rounded,
                      '${post['repost_count'] ?? 0}',
                      context.textSecondary,
                      () => _repost(index),
                    ),
                    const SizedBox(width: 24),
                    _buildActionBtn(
                      Icons.share_rounded,
                      'Share',
                      context.textSecondary,
                      () => _sharePost(index),
                    ),
                    GestureDetector(
                      onTap: () => _toggleBookmark(postId),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          isBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          key: ValueKey(isBookmarked),
                          color: isBookmarked
                              ? context.accent
                              : context.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Double-tap heart overlay
          if (showHeart)
            Positioned.fill(
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  builder: (_, val, child) =>
                      Transform.scale(scale: val, child: child),
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 80,
                    color: context.accent.withAlpha(200),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(
    IconData icon,
    String count,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 4),
          Text(
            count,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingView() {
    if (_trending.isEmpty) {
      return Center(
        child: Text(
          "Loading trending...",
          style: TextStyle(color: context.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _trending.length,
      itemBuilder: (context, index) {
        final tag = _trending[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
            boxShadow: [
              BoxShadow(
                color:
                    (context.isDark ? Colors.black : AsliColors.heritageBrown)
                        .withAlpha(10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    '#',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag['tag'] ?? '',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "Score: ${tag['score'] ?? 0}",
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.trending_up_rounded, color: context.accent, size: 24),
            ],
          ),
        );
      },
    );
  }
}
