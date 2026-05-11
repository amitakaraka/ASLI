import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

/// Story bar — horizontal scrollable row of story circles (Instagram-style)
class StoryBar extends StatefulWidget {
  const StoryBar({super.key});

  @override
  State<StoryBar> createState() => _StoryBarState();
}

class _StoryBarState extends State<StoryBar> {
  List<dynamic> _storyGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    final data = await ApiService.getStories();
    if (mounted) {
      setState(() {
        _storyGroups = data ?? [];
        _isLoading = false;
      });
    }
  }

  void _showCreateStory() {
    final textCtrl = TextEditingController();
    String selectedColor = '#E11D48';
    final colors = [
      '#E11D48', '#3B82F6', '#8B5CF6', '#10B981', '#F59E0B',
      '#EC4899', '#06B6D4', '#EF4444', '#6366F1', '#14B8A6',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20, right: 20, top: 20,
              ),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: context.borderColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text("Post Story", style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary,
                    )),
                    const SizedBox(height: 6),
                    Text("Disappears after 24 hours ⏳", style: TextStyle(
                      fontSize: 13, color: context.textSecondary,
                    )),
                    const SizedBox(height: 16),

                    // Story preview
                    Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        color: _parseColor(selectedColor),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      child: Text(
                        textCtrl.text.isEmpty ? "Your story text..." : textCtrl.text,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Text input
                    TextField(
                      controller: textCtrl,
                      maxLength: 200,
                      maxLines: 3,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: "What's happening on campus?",
                        hintStyle: TextStyle(color: context.textSecondary),
                        filled: true,
                        fillColor: context.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(color: context.textPrimary),
                    ),
                    const SizedBox(height: 12),

                    // Color picker
                    Text("Background Color", style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary,
                    )),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: colors.map((c) {
                        final isSelected = c == selectedColor;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: _parseColor(c),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: _parseColor(c).withAlpha(120),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ] : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (textCtrl.text.trim().isEmpty) return;
                          Navigator.pop(ctx);
                          await ApiService.createStory(textCtrl.text.trim(), selectedColor);
                          _loadStories();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Story posted! 📸")),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _parseColor(selectedColor),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Post Story", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openStoryViewer(Map<String, dynamic> group) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => StoryViewer(
          group: group,
          onDone: () => _loadStories(),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 100);
    }
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // "Add Story" button
          GestureDetector(
            onTap: _showCreateStory,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 62, height: 62,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: context.borderColor, width: 2),
                      color: context.isDark ? Colors.white.withAlpha(8) : AsliColors.lightAsh.withAlpha(70),
                    ),
                    child: Icon(Icons.add_rounded, color: context.accent, size: 28),
                  ),
                  const SizedBox(height: 6),
                  Text("Your Story", style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: context.textSecondary,
                  )),
                ],
              ),
            ),
          ),
          // Story circles
          ..._storyGroups.map((group) {
            final hasUnseen = group['has_unseen'] == true;
            final name = (group['creator_name'] ?? 'User').split(' ').first;
            final color = _parseColor(group['creator_color'] ?? '#A9523C');
            final stories = group['stories'] as List<dynamic>? ?? [];
            final firstBg = stories.isNotEmpty ? _parseColor(stories.first['bg_color'] ?? '#A9523C') : color;

            return GestureDetector(
              onTap: () => _openStoryViewer(Map<String, dynamic>.from(group)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Circle with gradient ring
                    Container(
                      width: 66, height: 66,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: hasUnseen
                            ? LinearGradient(
                                colors: [firstBg, color],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        border: hasUnseen ? null : Border.all(
                          color: context.borderColor,
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: BoxDecoration(
                          color: firstBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 64,
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: hasUnseen ? FontWeight.w700 : FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}


/// Full-screen story viewer with tap navigation and progress bars
class StoryViewer extends StatefulWidget {
  final Map<String, dynamic> group;
  final VoidCallback onDone;

  const StoryViewer({super.key, required this.group, required this.onDone});

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late List<dynamic> _stories;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _stories = widget.group['stories'] as List<dynamic>? ?? [];
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });
    _markViewed();
    _progressController.forward();
  }

  void _markViewed() {
    if (_currentIndex < _stories.length) {
      final storyId = _stories[_currentIndex]['id'];
      if (storyId != null) ApiService.viewStory(storyId);
    }
  }

  void _nextStory() {
    if (_currentIndex < _stories.length - 1) {
      setState(() => _currentIndex++);
      _markViewed();
      _progressController.reset();
      _progressController.forward();
    } else {
      _close();
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _progressController.reset();
      _progressController.forward();
    }
  }

  void _close() {
    widget.onDone();
    Navigator.of(context).pop();
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
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_stories.isEmpty) {
      return const SizedBox.shrink();
    }

    final story = _stories[_currentIndex];
    final bgColor = _parseColor(story['bg_color']);
    final creatorColor = _parseColor(widget.group['creator_color']);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final w = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < w / 3) {
            _prevStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          children: [
            // Background gradient
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    bgColor,
                    bgColor.withAlpha(200),
                    Colors.black87,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // Story content centered
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (story['emoji'] != null && (story['emoji'] as String).isNotEmpty) ...[
                      Text(story['emoji'], style: const TextStyle(fontSize: 48)),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      story['text'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                        shadows: [
                          Shadow(blurRadius: 20, color: Colors.black45, offset: Offset(0, 2)),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // Top: progress bars + user info
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress indicators
                    Row(
                      children: List.generate(_stories.length, (i) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: SizedBox(
                                height: 3,
                                child: i < _currentIndex
                                    ? Container(color: Colors.white)
                                    : i == _currentIndex
                                        ? AnimatedBuilder(
                                            animation: _progressController,
                                            builder: (_, __) {
                                              return LinearProgressIndicator(
                                                value: _progressController.value,
                                                backgroundColor: Colors.white30,
                                                valueColor: const AlwaysStoppedAnimation(Colors.white),
                                              );
                                            },
                                          )
                                        : Container(color: Colors.white30),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),

                    // User info + close
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: creatorColor,
                          child: Text(
                            (widget.group['creator_name'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.group['creator_name'] ?? 'Unknown',
                                style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14,
                                ),
                              ),
                              Text(
                                _timeAgo(story['created_at']),
                                style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _close,
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom: view count
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.visibility_rounded, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "${story['view_count'] ?? 0} views",
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
