import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';
import 'collx_post_detail_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<dynamic> _bookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getBookmarks();
    if (mounted) {
      setState(() {
        _bookmarks = data;
        _isLoading = false;
      });
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AsliColors.primaryMaroon;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return AsliColors.primaryMaroon; }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(dateStr));
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }

  Future<void> _removeBookmark(int postId, int index) async {
    final result = await ApiService.toggleBookmark(postId);
    if (result != null && mounted) {
      setState(() => _bookmarks.removeAt(index));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bookmark removed'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.bookmark_rounded, size: 22),
            const SizedBox(width: 8),
            const Text("Saved Posts", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${_bookmarks.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadBookmarks),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.accent))
          : _bookmarks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border_rounded, size: 64, color: context.textSecondary.withAlpha(100)),
                      const SizedBox(height: 16),
                      Text("No saved posts yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.textSecondary)),
                      const SizedBox(height: 8),
                      Text("Tap the bookmark icon on any post to save it here",
                          style: TextStyle(fontSize: 13, color: context.textSecondary.withAlpha(150))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBookmarks,
                  color: context.accent,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _bookmarks.length,
                    itemBuilder: (context, index) {
                      final bookmark = _bookmarks[index];
                      final post = bookmark['post'];
                      if (post == null) return const SizedBox.shrink();

                      final authorColor = _parseColor(post['author_color']);

                      return Dismissible(
                        key: Key('bookmark_${bookmark['id']}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(20),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.delete_rounded, color: Colors.red),
                        ),
                        onDismissed: (_) => _removeBookmark(post['id'], index),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => CollxPostDetailScreen(postId: post['id']),
                            ));
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Author row
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: authorColor,
                                      child: Text(
                                        (post['author'] ?? 'U')[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(post['author'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.textPrimary)),
                                          Text('@${post['author_username'] ?? ''}', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    // Bookmark filled icon
                                    IconButton(
                                      icon: Icon(Icons.bookmark_rounded, color: context.accent),
                                      iconSize: 22,
                                      onPressed: () => _removeBookmark(post['id'], index),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Content
                                Text(post['content'] ?? '', style: TextStyle(fontSize: 14, height: 1.4, color: context.textPrimary)),
                                const SizedBox(height: 10),
                                // Engagement + time
                                Row(
                                  children: [
                                    Icon(Icons.favorite_rounded, size: 14, color: context.accent.withAlpha(150)),
                                    const SizedBox(width: 4),
                                    Text('${post['like_count'] ?? 0}', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                    const SizedBox(width: 12),
                                    Icon(Icons.reply_rounded, size: 14, color: context.textSecondary.withAlpha(150)),
                                    const SizedBox(width: 4),
                                    Text('${post['reply_count'] ?? 0}', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                    const Spacer(),
                                    Icon(Icons.access_time_rounded, size: 12, color: context.textSecondary.withAlpha(120)),
                                    const SizedBox(width: 4),
                                    Text('Saved ${_timeAgo(bookmark['created_at'])}', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
