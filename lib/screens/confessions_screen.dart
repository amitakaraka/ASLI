import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

class ConfessionsScreen extends StatefulWidget {
  const ConfessionsScreen({super.key});

  @override
  State<ConfessionsScreen> createState() => _ConfessionsScreenState();
}

class _ConfessionsScreenState extends State<ConfessionsScreen> {
  List<dynamic> _confessions = [];
  List<String> _categories = [];
  List<String> _reactionEmojis = [];
  String _selectedCategory = '';
  bool _isLoading = true;

  static const _categoryIcons = {
    'general': '',
    'crush': '💘',
    'academics': '📖',
    'hostel': '🏠',
    'rant': '😤',
    'funny': '😂',
  };

  static const _categoryColors = {
    'general': AsliColors.primaryMaroon,
    'crush': AsliColors.accentPlum,
    'academics': AsliColors.accentTeal,
    'hostel': AsliColors.accentAmber,
    'rant': AsliColors.accentCoral,
    'funny': AsliColors.accentSage,
  };

  @override
  void initState() {
    super.initState();
    _loadConfessions();
  }

  Future<void> _loadConfessions() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getConfessions(
      category: _selectedCategory.isNotEmpty ? _selectedCategory : null,
    );
    if (!mounted) return;
    if (data != null) {
      setState(() {
        _confessions = data['confessions'] ?? [];
        _categories = List<String>.from(data['categories'] ?? []);
        _reactionEmojis = List<String>.from(data['reaction_emojis'] ?? []);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _showCreateConfession() {
    final contentCtrl = TextEditingController();
    String selectedCategory = 'general';
    String selectedMood = '😶';
    final moods = ['😶', '😍', '😔', '😤', '😂', '😎', '😋', '🥺', '😱', '🤔'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final catColor = _categoryColors[selectedCategory] ?? AsliColors.primaryMaroon;
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
                        decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text("🎭 ", style: TextStyle(fontSize: 22)),
                        Text("New Confession", style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary,
                        )),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("Your identity stays completely anonymous", style: TextStyle(
                      fontSize: 12, color: context.textSecondary, fontStyle: FontStyle.italic,
                    )),
                    const SizedBox(height: 14),

                    // Content field
                    TextField(
                      controller: contentCtrl,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: "What's on your mind? Spill it...",
                        hintStyle: TextStyle(color: context.textSecondary.withAlpha(120)),
                        filled: true,
                        fillColor: context.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        counterStyle: TextStyle(color: context.textSecondary, fontSize: 11),
                      ),
                      style: TextStyle(color: context.textPrimary, fontSize: 15),
                    ),
                    const SizedBox(height: 10),

                    // Category chips
                    Text("Category", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: _categoryIcons.entries.map((e) {
                        final isSel = e.key == selectedCategory;
                        final color = _categoryColors[e.key]!;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedCategory = e.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel ? color.withAlpha(30) : context.inputFill,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSel ? color : Colors.transparent, width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(e.value, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 4),
                                Text(e.key[0].toUpperCase() + e.key.substring(1), style: TextStyle(
                                  fontSize: 12, color: isSel ? color : context.textSecondary,
                                  fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                                )),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Mood selector
                    Text("Mood", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: moods.map((m) {
                        final isSel = m == selectedMood;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedMood = m),
                          child: Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: isSel ? catColor.withAlpha(30) : context.inputFill,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSel ? catColor : Colors.transparent, width: 2),
                            ),
                            child: Center(child: Text(m, style: const TextStyle(fontSize: 18))),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (contentCtrl.text.trim().isEmpty) return;
                          Navigator.pop(ctx);
                          await ApiService.createConfession(
                            contentCtrl.text.trim(),
                            category: selectedCategory,
                            mood: selectedMood,
                          );
                          _loadConfessions();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Confession posted anonymously! 🎭")),
                            );
                          }
                        },
                        icon: const Icon(Icons.send_rounded),
                        label: const Text("Post Anonymously", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: catColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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

  Future<void> _reactToConfession(int confessionId, String emoji) async {
    final result = await ApiService.reactConfession(confessionId, emoji);
    if (result != null && mounted) {
      _loadConfessions();
    }
  }

  void _showReactionPicker(int confessionId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("React", style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary,
              )),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _reactionEmojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _reactToConfession(confessionId, emoji);
                    },
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: context.inputFill,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  String _timeAgo(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: const Text("🎭 Confessions", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: context.isDark ? AsliColors.darkSurface : AsliColors.heritageBrown,
        foregroundColor: context.isDark ? AsliColors.darkText : Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Category filter chips
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: context.cardBg,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _filterChip('All', '', context.accent),
                  ..._categories.map((c) => _filterChip(
                    '${_categoryIcons[c] ?? ''} ${c[0].toUpperCase()}${c.substring(1)}',
                    c,
                    _categoryColors[c] ?? context.accent,
                  )),
                ],
              ),
            ),
          ),
          // Confessions list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: context.accent))
                : _confessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("🎭", style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 10),
                            Text("No confessions yet", style: TextStyle(
                              fontSize: 16, color: context.textSecondary,
                            )),
                            Text("Be the first to confess!", style: TextStyle(
                              fontSize: 13, color: context.textSecondary,
                            )),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadConfessions,
                        color: context.accent,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80, top: 6),
                          itemCount: _confessions.length,
                          itemBuilder: (_, i) => _buildConfessionCard(_confessions[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateConfession,
        backgroundColor: context.accent,
        icon: const Icon(Icons.edit_rounded, color: Colors.white),
        label: const Text("Confess", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _filterChip(String label, String value, Color color) {
    final isSel = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedCategory = value);
          _loadConfessions();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSel ? color : context.inputFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSel ? color : context.borderColor),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 13,
            color: isSel ? Colors.white : context.textSecondary,
            fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
          )),
        ),
      ),
    );
  }

  Widget _buildConfessionCard(dynamic confession) {
    final category = confession['category'] ?? 'general';
    final catColor = _categoryColors[category] ?? context.accent;
    final catIcon = _categoryIcons[category] ?? '';
    final mood = confession['mood'] ?? '😶';
    final reactionCount = confession['reaction_count'] ?? 0;
    final userReaction = confession['user_reaction'];
    final confessionId = confession['id'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(color: catColor.withAlpha(8), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: catColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(catIcon, style: const TextStyle(fontSize: 16))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text("Anonymous", style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary,
                          )),
                          const SizedBox(width: 6),
                          Text(mood, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                      Text(
                        "${category[0].toUpperCase()}${category.substring(1)} • ${_timeAgo(confession['created_at'])}",
                        style: TextStyle(fontSize: 11, color: catColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                // Confession ID tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: catColor.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text("#$confessionId", style: TextStyle(
                    fontSize: 11, color: catColor, fontWeight: FontWeight.w600,
                  )),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Text(
              confession['content'] ?? '',
              style: TextStyle(
                fontSize: 15, color: context.textPrimary, height: 1.5,
              ),
            ),
          ),

          // Reactions bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: context.inputFill.withAlpha(80),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(
              children: [
                // React button
                GestureDetector(
                  onTap: () {
                    if (userReaction != null) {
                      // Toggle off
                      _reactToConfession(confessionId, userReaction);
                    } else {
                      _showReactionPicker(confessionId);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: userReaction != null ? catColor.withAlpha(20) : context.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: userReaction != null ? catColor.withAlpha(80) : context.borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userReaction ?? '🤍',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "$reactionCount",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: userReaction != null ? catColor : context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Long press hint
                Text("Tap to react", style: TextStyle(
                  fontSize: 11, color: context.textSecondary.withAlpha(100),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
