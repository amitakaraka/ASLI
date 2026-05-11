import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

/// Reply card widget for displaying post replies
class ReplyCard extends StatelessWidget {
  final Map<String, dynamic> reply;
  final String timeAgo;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final bool isLiked;

  const ReplyCard({
    super.key,
    required this.reply,
    required this.timeAgo,
    this.onTap,
    this.onLike,
    this.isLiked = false,
  });

  @override
  Widget build(BuildContext context) {
    final isTemp = reply['isTemp'] == true;
    final authorName = reply['author_name'] ?? 'Unknown';
    final authorColor = reply['author_color'] ?? '#A9523C';
    final content = reply['content'] ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTemp 
              ? context.accent.withValues(alpha: 0.3)
              : context.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author header
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: _parseColor(authorColor),
                child: Text(
                  authorName[0].toUpperCase(),
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
                      authorName,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (isTemp)
                      Text(
                        'Sending...',
                        style: TextStyle(
                          color: context.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      Text(
                        timeAgo,
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
          // Reply content
          Text(
            content,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
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
}
