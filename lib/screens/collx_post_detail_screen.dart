import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';
import '../widgets/reply_card.dart';
import '../widgets/loading_shimmer.dart';
import '../widgets/error_view.dart';

/// CollX Post Detail Screen
/// Displays a single post with all replies and real-time updates
class CollxPostDetailScreen extends StatefulWidget {
  final int postId;
  
  const CollxPostDetailScreen({
    super.key,
    required this.postId,
  });

  @override
  State<CollxPostDetailScreen> createState() => _CollxPostDetailScreenState();
}

class _CollxPostDetailScreenState extends State<CollxPostDetailScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _replies = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isLiked = false;
  bool _isSendingReply = false;
  
  final _replyController = TextEditingController();
  final _replyFocusNode = FocusNode();
  final _scrollController = ScrollController();
  
  Timer? _refreshTimer;
  StreamSubscription? _socketSubscription;
  
  // Animation controllers
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadPost();
    _setupSocketListener();
    _startAutoRefresh();
  }

  void _setupAnimations() {
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _likeAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _setupSocketListener() {
    // Listen for real-time reply updates
    _socketSubscription = SocketService.instance.messageStream.listen((message) {
      // Check if this message is related to our post
      if (message.conversationId == 'post_${widget.postId}') {
        _silentRefresh();
      }
    });
  }

  void _startAutoRefresh() {
    // Silent refresh every 15 seconds to check for new replies
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _post != null) {
        _silentRefresh();
      }
    });
  }

  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await ApiService.getCollxPost(widget.postId);
      
      if (result != null && mounted) {
        setState(() {
          _post = result['data'];
          _replies = List<Map<String, dynamic>>.from(result['replies'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Post not found';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load post. Please check your connection.';
        });
      }
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _isSendingReply) return;

    setState(() {
      _isSendingReply = true;
    });

    try {
      // Optimistically add reply to UI
      final tempReply = {
        'id': -1,
        'content': text,
        'author_name': ApiService.currentUser?['name'] ?? 'You',
        'author_username': ApiService.currentUser?['username'] ?? 'you',
        'created_at': DateTime.now().toIso8601String(),
        'isTemp': true,
      };

      setState(() {
        _replies.add(tempReply);
      });

      _replyController.clear();
      _replyFocusNode.unfocus();

      // Send to API
      final success = await ApiService.replyCollxPost(widget.postId, text);
      
      if (success) {
        // Refresh to get actual reply from server
        await _silentRefresh();
        
        // Show success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Reply posted successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Remove temp reply on failure
        setState(() {
          _replies.removeWhere((r) => r['isTemp'] == true);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to post reply. Please try again.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _replies.removeWhere((r) => r['isTemp'] == true);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingReply = false;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;

    // Optimistic UI update
    setState(() {
      _isLiked = !_isLiked;
      _post!['like_count'] = (_post!['like_count'] ?? 0) + (_isLiked ? 1 : -1);
    });

    _likeAnimationController.forward().then((_) {
      _likeAnimationController.reverse();
    });

    try {
      final result = await ApiService.toggleCollxLike(widget.postId);
      
      if (result != null && mounted) {
        setState(() {
          _post!['like_count'] = result['like_count'];
          _isLiked = result['liked'] ?? _isLiked;
        });
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _isLiked = !_isLiked;
        _post!['like_count'] = (_post!['like_count'] ?? 0) + (_isLiked ? 1 : -1);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to like post'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _silentRefresh() async {
    try {
      final result = await ApiService.getCollxPost(widget.postId);
      if (result != null && mounted) {
        final newReplies = List<Map<String, dynamic>>.from(result['replies'] ?? []);
        
        // Only update if there are new replies
        if (newReplies.length != _replies.length) {
          setState(() {
            _post = result['data'];
            _replies = newReplies;
          });
        }
      }
    } catch (e) {
      // Silent fail - don't disturb user
    }
  }

  void _sharePost() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Share feature coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _reportPost() {
    // TODO: Implement report functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text('Are you sure you want to report this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Post reported. Thank you for keeping our community safe.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Report', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _copyPostText() {
    if (_post != null) {
      Clipboard.setData(ClipboardData(text: _post!['content'] ?? ''));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _socketSubscription?.cancel();
    _replyController.dispose();
    _replyFocusNode.dispose();
    _scrollController.dispose();
    _likeAnimationController.dispose();
    super.dispose();
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AsliColors.primaryMaroon;
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
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "Post Details",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      elevation: 0,
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, size: 22),
          onPressed: _sharePost,
          tooltip: 'Share',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 22),
          onSelected: (value) {
            if (value == 'copy') _copyPostText();
            if (value == 'report') _reportPost();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'copy',
              child: Row(
                children: [
                  Icon(Icons.copy, size: 20),
                  SizedBox(width: 12),
                  Text('Copy text'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Report', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_post == null) {
      return _buildEmptyState();
    }

    return _buildContent();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShimmerLoading(
            width: 200,
            height: 200,
            borderRadius: 16,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading post...',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return ErrorView(
      message: _errorMessage ?? 'Something went wrong',
      onRetry: _loadPost,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.post_add_outlined,
            size: 80,
            color: context.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Post not found',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This post may have been deleted',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPost,
            color: context.accent,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: _buildPostCard(),
                  ),
                ),
                
                // Replies header
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Replies (${_replies.length})",
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (_replies.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              // Scroll to bottom
                              _scrollController.animateTo(
                                _scrollController.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: const Text('Latest'),
                          ),
                      ],
                    ),
                  ),
                ),

                // Replies list
                if (_replies.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(
                      child: _buildEmptyReplies(),
                    ),
                  ),
                
                ..._replies.map((reply) => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  sliver: SliverToBoxAdapter(
                    child: ReplyCard(
                      reply: reply,
                      timeAgo: _timeAgo(reply['created_at']),
                    ),
                  ),
                )),

                // Bottom padding for reply input
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),
        ),
        
        // Reply input
        _buildReplyInput(),
      ],
    );
  }

  Widget _buildPostCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: (context.isDark ? Colors.black : AsliColors.heritageBrown).withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author section
          _buildAuthorSection(),
          
          const SizedBox(height: 16),
          
          // Post content
          Text(
            _post!['content'] ?? '',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 17,
              height: 1.5,
            ),
          ),
          
          // Hashtags (if any)
          if (_post!['hashtags'] != null && _post!['hashtags'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (_post!['hashtags'] as String).split(',').map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tag.trim(),
                      style: TextStyle(
                        color: context.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          
          const SizedBox(height: 12),
          
          // Timestamp
          Text(
            _timeAgo(_post!['created_at']),
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Divider
          Container(
            height: 1,
            color: context.borderColor,
          ),
          
          // Stats and actions
          _buildActionsSection(),
        ],
      ),
    );
  }

  Widget _buildAuthorSection() {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: _parseColor(_post!['author_color'] ?? '#A9523C'),
          child: Text(
            (_post!['author_name'] ?? 'U')[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _post!['author_name'] ?? 'Unknown',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                "@${_post!['author_username'] ?? 'user'}",
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        // Follow button (if not own post)
        if (_post!['user_id'] != ApiService.currentUserId)
          ElevatedButton(
            onPressed: () {
              // TODO: Implement follow
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Follow'),
          ),
      ],
    );
  }

  Widget _buildActionsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Like button
          _buildActionButton(
            icon: AnimatedBuilder(
              animation: _likeAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _likeAnimation.value,
                  child: Icon(
                    _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _isLiked ? Colors.red : context.textSecondary,
                    size: 24,
                  ),
                );
              },
            ),
            label: '${_post!['like_count'] ?? 0}',
            onTap: _toggleLike,
          ),
          
          // Reply button
          _buildActionButton(
            icon: Icon(
              Icons.chat_bubble_outline_rounded,
              color: context.textSecondary,
              size: 24,
            ),
            label: '${_replies.length}',
            onTap: () {
              _replyFocusNode.requestFocus();
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
          
          // Repost button
          _buildActionButton(
            icon: Icon(
              Icons.repeat_rounded,
              color: context.textSecondary,
              size: 24,
            ),
            label: '${_post!['repost_count'] ?? 0}',
            onTap: () {
              // TODO: Implement repost
            },
          ),
          
          // Share button
          _buildActionButton(
            icon: Icon(
              Icons.share_rounded,
              color: context.textSecondary,
              size: 24,
            ),
            label: 'Share',
            onTap: _sharePost,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyReplies() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 48,
            color: context.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No replies yet',
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Be the first to reply!',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: context.surfaceBg,
        border: Border(
          top: BorderSide(color: context.borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: (context.isDark ? Colors.black : AsliColors.heritageBrown).withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: context.inputFill,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.borderColor),
                ),
                child: TextField(
                  controller: _replyController,
                  focusNode: _replyFocusNode,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: "Write a reply...",
                    hintStyle: TextStyle(
                      color: context.textSecondary,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 0,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.image_outlined,
                            color: context.textSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            // TODO: Implement image picker
                          },
                          tooltip: 'Add image',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.emoji_emotions_outlined,
                            color: context.textSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            // TODO: Implement emoji picker
                          },
                          tooltip: 'Add emoji',
                        ),
                      ],
                    ),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  onSubmitted: (_) => _sendReply(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: _isSendingReply ? context.accent.withValues(alpha: 0.5) : context.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: _isSendingReply
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                onPressed: _isSendingReply ? null : _sendReply,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
