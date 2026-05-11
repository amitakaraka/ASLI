import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

/// Post card widget for CollX feed
class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onReply;
  final VoidCallback? onShare;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onLike,
    this.onReply,
    this.onShare,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  void _handleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });

    _likeAnimationController.forward().then((_) {
      _likeAnimationController.reverse();
    });

    widget.onLike?.call();
  }

  @override
  Widget build(BuildContext context) {
    final authorName = widget.post['author_name'] ?? 'Unknown';
    final authorUsername = widget.post['author_username'] ?? 'user';
    final authorColor = widget.post['author_color'] ?? '#A9523C';
    final content = widget.post['content'] ?? '';
    final likeCount = widget.post['like_count'] ?? 0;
    final replyCount = widget.post['reply_count'] ?? 0;
    final repostCount = widget.post['repost_count'] ?? 0;
    final createdAt = widget.post['created_at'];
    final hashtags = widget.post['hashtags'] ?? '';
    final imageUrl = widget.post['image_url'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: (context.isDark ? Colors.black : AsliColors.heritageBrown).withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header - Author info
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _parseColor(authorColor),
                    child: Text(
                      authorName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '@$authorUsername · ${_timeAgo(createdAt)}',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // More options
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz,
                      color: context.textSecondary,
                    ),
                    onSelected: (value) {
                      // TODO: Handle menu actions
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share, size: 20),
                            SizedBox(width: 12),
                            Text('Share'),
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
              ),

              const SizedBox(height: 12),

              // Post content
              Text(
                content,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),

              // Hashtags
              if (hashtags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: hashtags.split(',').map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        tag.trim(),
                        style: TextStyle(
                          color: context.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Image (if any)
              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: context.inputFill,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor: AlwaysStoppedAnimation<Color>(context.accent),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: context.inputFill,
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: context.textSecondary,
                            size: 40,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Divider
              Container(
                height: 1,
                color: context.borderColor,
              ),

              const SizedBox(height: 12),

              // Action buttons
              Row(
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
                            size: 22,
                          ),
                        );
                      },
                    ),
                    label: '$likeCount',
                    onTap: _handleLike,
                  ),

                  // Reply button
                  _buildActionButton(
                    icon: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: context.textSecondary,
                      size: 22,
                    ),
                    label: '$replyCount',
                    onTap: widget.onReply,
                  ),

                  // Repost button
                  _buildActionButton(
                    icon: Icon(
                      Icons.repeat_rounded,
                      color: context.textSecondary,
                      size: 22,
                    ),
                    label: '$repostCount',
                    onTap: () {
                      // TODO: Implement repost
                    },
                  ),

                  // Share button
                  _buildActionButton(
                    icon: Icon(
                      Icons.share_rounded,
                      color: context.textSecondary,
                      size: 22,
                    ),
                    label: 'Share',
                    onTap: widget.onShare,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required Widget icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 2),
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
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return '';
    }
  }
}
