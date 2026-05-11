import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';
import 'user_profile_screen.dart';
import 'collx_post_detail_screen.dart';
import 'dart:async';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<dynamic> _users = [];
  List<dynamic> _posts = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (query.length >= 2) {
        _search(query);
      } else {
        setState(() { _users = []; _posts = []; _hasSearched = false; });
      }
    });
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    final result = await ApiService.searchCollx(query);
    if (result != null && mounted) {
      setState(() {
        _users = result['users'] ?? [];
        _posts = result['posts'] ?? [];
        _isSearching = false;
        _hasSearched = true;
      });
    } else {
      setState(() => _isSearching = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: const Text("Search", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: context.accent.withAlpha(8),
            child: TextField(
              controller: _controller,
              onChanged: _onSearchChanged,
              autofocus: true,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search users, posts, hashtags...',
                hintStyle: TextStyle(color: context.textSecondary),
                prefixIcon: Icon(Icons.search_rounded, color: context.accent),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: context.textSecondary),
                        onPressed: () {
                          _controller.clear();
                          setState(() { _users = []; _posts = []; _hasSearched = false; });
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // Results
          Expanded(
            child: _isSearching
                ? Center(child: CircularProgressIndicator(color: context.accent))
                : !_hasSearched
                    ? _buildSuggestions()
                    : (_users.isEmpty && _posts.isEmpty)
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 48, color: context.textSecondary.withAlpha(100)),
                                const SizedBox(height: 12),
                                Text("No results found", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textSecondary)),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(12),
                            children: [
                              // Users section
                              if (_users.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Icon(Icons.people_rounded, size: 18, color: context.accent),
                                      const SizedBox(width: 6),
                                      Text('People (${_users.length})', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary)),
                                    ],
                                  ),
                                ),
                                ..._users.map((u) => _buildUserTile(u)),
                                const SizedBox(height: 16),
                              ],

                              // Posts section
                              if (_posts.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Icon(Icons.article_rounded, size: 18, color: context.accent),
                                      const SizedBox(width: 6),
                                      Text('Posts (${_posts.length})', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary)),
                                    ],
                                  ),
                                ),
                                ..._posts.map((p) => _buildPostTile(p)),
                              ],
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = ['#Hackathon', '#ML', '#Placements', '#Research', '#IoT', '#Startup'];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Try searching for', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((s) => GestureDetector(
              onTap: () {
                _controller.text = s;
                _search(s);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: context.accent.withAlpha(10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.accent.withAlpha(30)),
                ),
                child: Text(s, style: TextStyle(color: context.accent, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 24),
          Text('Popular categories', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textPrimary)),
          const SizedBox(height: 12),
          _categoryTile(Icons.code_rounded, 'Tech & Coding', AsliColors.accentTeal),
          _categoryTile(Icons.school_rounded, 'Academics', AsliColors.accentSage),
          _categoryTile(Icons.work_rounded, 'Placements', AsliColors.accentAmber),
          _categoryTile(Icons.groups_rounded, 'Campus Life', AsliColors.accentCoral),
        ],
      ),
    );
  }

  Widget _categoryTile(IconData icon, String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.textPrimary)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, color: context.textSecondary, size: 20),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final color = _parseColor(user['profile_color']);
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: user['id']),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color,
              child: Text((user['name'] ?? 'U')[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.textPrimary)),
                  Text('@${user['username'] ?? ''} • ${user['department'] ?? ''}', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: context.accent.withAlpha(10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${user['follower_count'] ?? 0} followers', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.accent)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostTile(Map<String, dynamic> post) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => CollxPostDetailScreen(postId: post['id']),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
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
                  radius: 14,
                  backgroundColor: _parseColor(post['author_color']),
                  child: Text((post['author'] ?? 'U')[0], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text(post['author'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.textPrimary)),
                const Spacer(),
                Text(_timeAgo(post['created_at']), style: TextStyle(fontSize: 11, color: context.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            Text(post['content'] ?? '', style: TextStyle(fontSize: 13, height: 1.3, color: context.textPrimary), maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.favorite_rounded, size: 14, color: context.accent.withAlpha(150)),
                const SizedBox(width: 3),
                Text('${post['like_count'] ?? 0}', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                const SizedBox(width: 10),
                Icon(Icons.reply_rounded, size: 14, color: context.textSecondary.withAlpha(150)),
                const SizedBox(width: 3),
                Text('${post['reply_count'] ?? 0}', style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
