import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _stats;
  List<dynamic> _activity = [];
  List<dynamic> _leaderboard = [];
  List<dynamic> _modules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService.getAnalyticsStats(),
      ApiService.getActivityFeed(),
      ApiService.getLeaderboard(),
      ApiService.getModuleHealth(),
    ]);
    if (mounted) {
      setState(() {
        _stats = results[0] as Map<String, dynamic>?;
        _activity = results[1] as List<dynamic>;
        _leaderboard = results[2] as List<dynamic>;
        _modules = results[3] as List<dynamic>;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: const Text("Analytics", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: "Overview"),
            Tab(text: "Activity"),
            Tab(text: "Leaders"),
            Tab(text: "System"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.accent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverview(),
                _buildActivity(),
                _buildLeaderboard(),
                _buildSystem(),
              ],
            ),
    );
  }

  // ==================== TAB 1: OVERVIEW ====================
  Widget _buildOverview() {
    if (_stats == null) return const Center(child: Text("No data available"));
    return RefreshIndicator(
      onRefresh: _loadData,
      color: context.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero stat cards
          Row(
            children: [
              Expanded(child: _statCard(
                Icons.people_rounded, "Users",
                '${_stats!['users']?['total'] ?? 0}',
                AsliColors.accentIndigo,
              )),
              const SizedBox(width: 12),
              Expanded(child: _statCard(
                Icons.article_rounded, "Posts",
                '${_stats!['posts']?['total'] ?? 0}',
                AsliColors.accentCoral,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statCard(
                Icons.favorite_rounded, "Likes",
                '${_stats!['interactions']?['likes'] ?? 0}',
                AsliColors.accentAmber,
              )),
              const SizedBox(width: 12),
              Expanded(child: _statCard(
                Icons.reply_rounded, "Replies",
                '${_stats!['interactions']?['replies'] ?? 0}',
                AsliColors.accentTeal,
              )),
            ],
          ),
          const SizedBox(height: 20),

          // Engagement rate bar
          _buildEngagementCard(),
          const SizedBox(height: 16),

          // Q&A stats
          _buildQACard(),
          const SizedBox(height: 16),

          // Top post
          if (_stats!['top_post'] != null) _buildTopPostCard(),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(30)),
        boxShadow: [
          BoxShadow(color: color.withAlpha(15), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 13, color: context.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEngagementCard() {
    final rate = (_stats!['engagement_rate'] ?? 0).toDouble();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AsliColors.primaryMaroon, AsliColors.primaryMaroon.withAlpha(180)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text("Engagement Rate", style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Text("${rate.toStringAsFixed(1)}%",
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (rate / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text("(Likes + Replies) / Posts × 100",
              style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildQACard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AsliColors.accentTeal.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.forum_rounded, color: AsliColors.accentTeal, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Q&A Forum", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: context.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  "${_stats!['qa']?['questions'] ?? 0} questions · ${_stats!['qa']?['answers'] ?? 0} answers",
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            "${_stats!['notifications_sent'] ?? 0}",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AsliColors.accentPlum),
          ),
          const SizedBox(width: 4),
          Text("notifs", style: TextStyle(fontSize: 11, color: context.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTopPostCard() {
    final post = _stats!['top_post'];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AsliColors.accentCoral.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: AsliColors.accentAmber, size: 20),
              const SizedBox(width: 6),
              Text("Most Popular Post", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AsliColors.accentCoral.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                child: Text("❤️ ${post['like_count']}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AsliColors.accentCoral)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(post['content'] ?? '', style: TextStyle(fontSize: 14, color: context.textPrimary)),
          const SizedBox(height: 6),
          Text("— ${post['author_name'] ?? 'Unknown'}", style: TextStyle(fontSize: 12, color: context.textSecondary)),
        ],
      ),
    );
  }

  // ==================== TAB 2: ACTIVITY ====================
  Widget _buildActivity() {
    if (_activity.isEmpty) {
      return Center(child: Text("No recent activity", style: TextStyle(color: context.textSecondary)));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: context.accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _activity.length,
        itemBuilder: (context, index) {
          final a = _activity[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _parseColor(a['color']).withAlpha(25),
                  child: Icon(_parseIcon(a['icon']), color: _parseColor(a['color']), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a['title'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.textPrimary)),
                      if (a['detail']?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(a['detail'], style: TextStyle(fontSize: 12, color: context.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
                Text(_timeAgo(a['time']), style: TextStyle(fontSize: 11, color: context.textSecondary)),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==================== TAB 3: LEADERBOARD ====================
  Widget _buildLeaderboard() {
    if (_leaderboard.isEmpty) return const Center(child: Text("No data"));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _leaderboard.length,
      itemBuilder: (context, index) {
        final u = _leaderboard[index];
        final rank = index + 1;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: rank <= 3 ? _getRankColor(rank).withAlpha(8) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: rank <= 3 ? _getRankColor(rank).withAlpha(40) : context.borderColor),
          ),
          child: Row(
            children: [
              // Rank badge
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _getRankColor(rank).withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: rank <= 3
                      ? Text(_getRankEmoji(rank), style: const TextStyle(fontSize: 18))
                      : Text('$rank', style: TextStyle(fontWeight: FontWeight.bold, color: _getRankColor(rank), fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: _parseColor(u['profile_color']),
                child: Text(
                  (u['name'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary)),
                    Text(
                      "${u['posts']} posts · ${u['likes_received']} likes · ${u['followers']} followers",
                      style: TextStyle(fontSize: 11, color: context.textSecondary),
                    ),
                  ],
                ),
              ),
              // Score
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _getRankColor(rank).withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${u['score']}',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _getRankColor(rank)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== TAB 4: SYSTEM ====================
  Widget _buildSystem() {
    if (_modules.isEmpty) return const Center(child: Text("No data"));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Platform header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AsliColors.heritageBrown, AsliColors.primaryMaroon],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("ASLI Platform", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text("v6.0.0 — Analytics Dashboard", style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _systemBadge("${_modules.length} Modules"),
                  const SizedBox(width: 8),
                  _systemBadge("SQLite"),
                  const SizedBox(width: 8),
                  _systemBadge("JWT Auth"),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text("Active Modules", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
        const SizedBox(height: 10),
        ..._modules.map((m) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _parseColor(m['color']).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_parseModuleIcon(m['icon']), color: _parseColor(m['color']), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary)),
                    Text(m['stats'] ?? '', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AsliColors.statusSuccess.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: AsliColors.statusSuccess, size: 14),
                    SizedBox(width: 4),
                    Text("Active", style: TextStyle(color: AsliColors.statusSuccess, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _systemBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  // ==================== HELPERS ====================
  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AsliColors.primaryMaroon;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AsliColors.primaryMaroon;
    }
  }

  IconData _parseIcon(String? name) {
    switch (name) {
      case 'edit': return Icons.edit_note_rounded;
      case 'reply': return Icons.reply_rounded;
      case 'person_add': return Icons.person_add_rounded;
      default: return Icons.circle;
    }
  }

  IconData _parseModuleIcon(String? name) {
    switch (name) {
      case 'lock': return Icons.lock_rounded;
      case 'chat': return Icons.chat_rounded;
      case 'forum': return Icons.forum_rounded;
      case 'public': return Icons.public_rounded;
      case 'event': return Icons.event_rounded;
      case 'notifications': return Icons.notifications_rounded;
      case 'analytics': return Icons.analytics_rounded;
      default: return Icons.extension_rounded;
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1: return AsliColors.accentAmber;
      case 2: return AsliColors.accentSienna;
      case 3: return AsliColors.accentRust;
      default: return AsliColors.stoneBrown;
    }
  }

  String _getRankEmoji(int rank) {
    switch (rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '$rank';
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) {
      return '';
    }
  }
}
