import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonLoader extends StatelessWidget {
  final Widget child;
  final bool isLoading;

  const SkeletonLoader({super.key, required this.child, this.isLoading = true});

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;
    return child;
  }
}

class SkeletonCard extends StatelessWidget {
  final double? height;
  final double? width;
  final double borderRadius;

  const SkeletonCard({
    super.key,
    this.height,
    this.width,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      ),
    );
  }
}

class SkeletonText extends StatelessWidget {
  final int lines;
  final double lineHeight;
  final double spacing;

  const SkeletonText({
    super.key,
    this.lines = 3,
    this.lineHeight = 14,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(lines, (i) {
          final isLast = i == lines - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: i < lines - 1 ? spacing : 0),
            child: Container(
              height: lineHeight,
              width: isLast
                  ? (i == 0 ? 200 : double.infinity)
                  : double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class SkeletonRect extends StatelessWidget {
  final double height;
  final double width;
  final double borderRadius;

  const SkeletonRect({
    super.key,
    this.height = 100,
    this.width = double.infinity,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class PostSkeletonLoader extends StatelessWidget {
  const PostSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonCircle(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonText(lines: 1, lineHeight: 14),
                    const SizedBox(height: 4),
                    SkeletonText(lines: 1, lineHeight: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonText(lines: 2, lineHeight: 14),
          const SizedBox(height: 14),
          Row(
            children: [
              SkeletonRect(height: 32, width: 60, borderRadius: 16),
              const SizedBox(width: 16),
              SkeletonRect(height: 32, width: 60, borderRadius: 16),
            ],
          ),
        ],
      ),
    );
  }
}

class EventCardSkeleton extends StatelessWidget {
  const EventCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withAlpha(25),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const SkeletonRect(height: 48, width: 48, borderRadius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonRect(height: 20, width: 100, borderRadius: 8),
                      const SizedBox(height: 8),
                      SkeletonText(lines: 1, lineHeight: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(lines: 2, lineHeight: 14),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SkeletonRect(height: 28, width: 80, borderRadius: 14),
                    const SizedBox(width: 8),
                    SkeletonRect(height: 28, width: 80, borderRadius: 14),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubbleSkeleton extends StatelessWidget {
  final bool isUser;

  const ChatBubbleSkeleton({super.key, this.isUser = false});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isUser ? 60 : 0,
          right: isUser ? 0 : 60,
          bottom: 8,
        ),
        child: Shimmer.fromColors(
          baseColor: isUser
              ? Theme.of(context).primaryColor.withAlpha(180)
              : Theme.of(context).cardColor,
          highlightColor: isUser
              ? Theme.of(context).primaryColor.withAlpha(100)
              : Theme.of(context).dividerColor,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 6),
                bottomRight: Radius.circular(isUser ? 6 : 20),
              ),
            ),
            child: SkeletonText(lines: 2, lineHeight: 14, spacing: 6),
          ),
        ),
      ),
    );
  }
}

class PollSkeletonLoader extends StatelessWidget {
  const PollSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonText(lines: 2, lineHeight: 16),
          const SizedBox(height: 16),
          ...List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SkeletonRect(height: 44, borderRadius: 12),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SkeletonRect(height: 20, width: 60, borderRadius: 10),
              const SizedBox(width: 12),
              SkeletonRect(height: 20, width: 80, borderRadius: 10),
            ],
          ),
        ],
      ),
    );
  }
}

class ListItemSkeleton extends StatelessWidget {
  final bool showAvatar;
  final bool showSubtitle;

  const ListItemSkeleton({
    super.key,
    this.showAvatar = true,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (showAvatar) ...[
            const SkeletonCircle(size: 52),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(lines: 1, lineHeight: 16),
                if (showSubtitle) ...[
                  const SizedBox(height: 6),
                  SkeletonText(lines: 1, lineHeight: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
