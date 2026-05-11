import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';
import 'dm_chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _user;
  List<dynamic> _posts = [];
  bool _isLoading = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getCollxUser(widget.userId);
    if (data != null && mounted) {
      setState(() {
        _user = data['data'];
        _posts = data['posts'] ?? [];
        _isFollowing = data['data']?['is_following'] ?? false;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final result = await ApiService.toggleCollxFollow(widget.userId);
    if (result != null && mounted) {
      setState(() => _isFollowing = result['following'] ?? false);
      _loadProfile();
    }
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
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMe = widget.userId == ApiService.currentUserId;
    final color = _parseColor(_user?['profile_color']);

    return Scaffold(
      backgroundColor: context.pageBg,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: context.accent),
            )
          : _user == null
          ? const Center(child: Text("User not found"))
          : RefreshIndicator(
              onRefresh: _loadProfile,
              color: context.accent,
              child: CustomScrollView(
              slivers: [
                // Hero Header
                SliverAppBar(
                  expandedHeight: 260,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            color,
                            color.withAlpha(180),
                            context.pageBg,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 30),
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 38,
                                backgroundColor: color,
                                child: Text(
                                  (_user!['name'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _user!['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '@${_user!['username'] ?? ''}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withAlpha(200),
                              ),
                            ),
                            if (_user!['bio']?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  _user!['bio'],
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withAlpha(220),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Stats bar
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statItem(context, '${_posts.length}', 'Posts'),
                        Container(width: 1, height: 30, color: context.borderColor),
                        _statItem(context, '${_user!['follower_count'] ?? 0}', 'Followers'),
                        Container(width: 1, height: 30, color: context.borderColor),
                        _statItem(context, '${_user!['following_count'] ?? 0}', 'Following'),
                        Container(width: 1, height: 30, color: context.borderColor),
                        _statItem(context, _user!['department'] ?? '', _user!['year'] ?? ''),
                      ],
                    ),
                  ),
                ),

                // Action buttons
                if (!isMe)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _toggleFollow,
                              icon: Icon(
                                _isFollowing
                                    ? Icons.person_remove_rounded
                                    : Icons.person_add_rounded,
                                size: 18,
                              ),
                              label: Text(_isFollowing ? 'Unfollow' : 'Follow'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFollowing
                                    ? (context.isDark ? AsliColors.darkCard : Colors.grey.shade200)
                                    : context.accent,
                                foregroundColor: _isFollowing
                                    ? context.textPrimary
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DMChatScreen(
                                      partnerId: widget.userId,
                                      partnerName: _user!['name'] ?? 'User',
                                      partnerColor: _user!['profile_color'] ?? '#A9523C',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.mail_outline_rounded, size: 18),
                              label: const Text('Message'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: context.accent,
                                side: BorderSide(color: context.accent),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Posts header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
                    child: Text(
                      _posts.isEmpty ? 'No posts yet' : 'Posts (${_posts.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ),

                // Posts list
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildPostCard(context, _posts[index]),
                    childCount: _posts.length,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            ),
          ),
    );
  }

  Widget _statItem(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.textSecondary),
        ),
      ],
    );
  }

  Widget _buildPostCard(BuildContext context, Map<String, dynamic> post) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post['content'] ?? '',
            style: TextStyle(fontSize: 14, height: 1.4, color: context.textPrimary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.favorite_rounded, size: 15, color: context.accent.withAlpha(150)),
              const SizedBox(width: 4),
              Text('${post['like_count'] ?? 0}', style: TextStyle(fontSize: 12, color: context.textSecondary)),
              const SizedBox(width: 14),
              Icon(Icons.reply_rounded, size: 15, color: context.textSecondary.withAlpha(150)),
              const SizedBox(width: 4),
              Text('${post['reply_count'] ?? 0}', style: TextStyle(fontSize: 12, color: context.textSecondary)),
              const Spacer(),
              Text(_timeAgo(post['created_at']), style: TextStyle(fontSize: 11, color: context.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
