import 'package:flutter/material.dart';

/// Shimmer loading effect widget
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1, end: 2).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                _animation.value - 0.5,
                _animation.value,
                _animation.value + 0.5,
              ],
              colors: [
                widget.baseColor ?? Colors.grey[300]!,
                widget.highlightColor ?? Colors.grey[100]!,
                widget.baseColor ?? Colors.grey[300]!,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Post card shimmer placeholder
class PostCardShimmer extends StatelessWidget {
  const PostCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar and name
          Row(
            children: [
              const ShimmerLoading(width: 40, height: 40, borderRadius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerLoading(width: 120, height: 14, borderRadius: 7),
                    const SizedBox(height: 6),
                    const ShimmerLoading(width: 80, height: 12, borderRadius: 6),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Content lines
          const ShimmerLoading(width: double.infinity, height: 14, borderRadius: 7),
          const SizedBox(height: 8),
          const ShimmerLoading(width: double.infinity, height: 14, borderRadius: 7),
          const SizedBox(height: 8),
          const ShimmerLoading(width: 200, height: 14, borderRadius: 7),
          const SizedBox(height: 16),
          // Actions
          Row(
            children: [
              const ShimmerLoading(width: 60, height: 30, borderRadius: 15),
              const SizedBox(width: 16),
              const ShimmerLoading(width: 60, height: 30, borderRadius: 15),
              const SizedBox(width: 16),
              const ShimmerLoading(width: 60, height: 30, borderRadius: 15),
            ],
          ),
        ],
      ),
    );
  }
}

/// Feed list shimmer
class FeedShimmer extends StatelessWidget {
  final int itemCount;

  const FeedShimmer({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => const PostCardShimmer(),
    );
  }
}
