import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _leaderboard = [];
  Map<String, dynamic>? _myRank;
  bool _isLoading = true;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    final data = await ApiService.getEngagementLeaderboard();
    if (mounted && data != null) {
      setState(() {
        _leaderboard = data['leaderboard'] ?? [];
        _myRank = data['my_rank'];
        _isLoading = false;
      });
      _animCtrl.forward();
    } else if (mounted) {
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: const Text(
          "Leaderboard",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: context.isDark ? AsliColors.darkSurface : AsliColors.heritageBrown,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _showPointsInfo,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: context.accent),
            )
          : _leaderboard.isEmpty
          ? const Center(child: Text("No data yet"))
          : RefreshIndicator(
              onRefresh: _loadLeaderboard,
              color: context.accent,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 30),
                children: [
                  // My rank card
                  if (_myRank != null) _buildMyRankCard(),
                  // Top 3 podium
                  if (_leaderboard.length >= 3) _buildPodium(),
                  const SizedBox(height: 8),
                  // Full list
                  ..._leaderboard.asMap().entries.map(
                    (e) => _buildRankRow(e.key, e.value),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMyRankCard() {
    final rank = _myRank!;
    final badgeColor = _parseColor(rank['rank_color']);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [badgeColor.withAlpha(40), badgeColor.withAlpha(15)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withAlpha(80)),
      ),
      child: Row(
        children: [
          // Rank number
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                "#${rank['position']}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Your Rank",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      rank['rank_emoji'] ?? '🌱',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${rank['rank']} • ${rank['points']} pts",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Points breakdown mini
          GestureDetector(
            onTap: () => _showBreakdown(rank),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: badgeColor.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Details",
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium() {
    final top3 = _leaderboard.take(3).toList();
    // Reorder for podium: [2nd, 1st, 3rd]
    final podiumOrder = [
      if (top3.length > 1) top3[1],
      top3[0],
      if (top3.length > 2) top3[2],
    ];
    final heights = [110.0, 140.0, 90.0];
    final medals = ['🥈', '🥇', '🥉'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.only(top: 16, bottom: 0),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Text(
            "Top 3 Campus Leaders",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(podiumOrder.length, (i) {
              final user = podiumOrder[i];
              final color = _parseColor(user['profile_color']);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(medals[i], style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    CircleAvatar(
                      radius: i == 1 ? 30 : 24,
                      backgroundColor: color,
                      child: Text(
                        (user['name'] ?? 'U')[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: i == 1 ? 22 : 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (user['name'] ?? 'Unknown').split(' ').first,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      "${user['points']} pts",
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: i == 1 ? 80 : 65,
                      height: heights[i],
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withAlpha(150), color.withAlpha(60)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "#${user['position']}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRankRow(int index, Map<String, dynamic> user) {
    final pos = user['position'] ?? (index + 1);
    final color = _parseColor(user['profile_color']);
    final badgeColor = _parseColor(user['rank_color']);
    final isMyRank = _myRank != null && _myRank!['user_id'] == user['user_id'];

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (_, child) {
        final delay = (index * 0.08).clamp(0.0, 0.6);
        final t = Curves.easeOutCubic.transform(
          ((_animCtrl.value - delay) / (1 - delay)).clamp(0.0, 1.0),
        );
        return Transform.translate(
          offset: Offset(0, 30 * (1 - t)),
          child: Opacity(opacity: t, child: child),
        );
      },
      child: GestureDetector(
        onTap: () => _showBreakdown(user),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isMyRank ? badgeColor.withAlpha(20) : context.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMyRank ? badgeColor.withAlpha(100) : context.borderColor,
            ),
          ),
          child: Row(
            children: [
              // Position
              SizedBox(
                width: 30,
                child: Text(
                  "$pos",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: pos <= 3 ? badgeColor : context.textSecondary,
                  ),
                ),
              ),
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: color,
                child: Text(
                  (user['name'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name + badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['name'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          user['rank_emoji'] ?? '🌱',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user['rank'] ?? 'Newcomer',
                          style: TextStyle(
                            fontSize: 12,
                            color: badgeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (user['department'] != null &&
                            (user['department'] as String).isNotEmpty) ...[
                          Text(
                            " • ",
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              user['department'],
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Points
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${user['points']} pts",
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBreakdown(Map<String, dynamic> user) {
    final breakdown = user['breakdown'] as Map<String, dynamic>? ?? {};
    final badgeColor = _parseColor(user['rank_color']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _parseColor(user['profile_color']),
                  child: Text(
                    (user['name'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  user['name'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user['rank_emoji'] ?? '🌱',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${user['rank']} • #${user['position']} • ${user['points']} pts",
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Breakdown grid
                _breakdownTile(
                  "Posts",
                  breakdown['posts'] ?? 0,
                  10,
                  Icons.article_rounded,
                  AsliColors.accentTeal,
                ),
                _breakdownTile(
                  "Replies",
                  breakdown['replies'] ?? 0,
                  5,
                  Icons.reply_rounded,
                  AsliColors.accentIndigo,
                ),
                _breakdownTile(
                  "Likes Given",
                  breakdown['likes_given'] ?? 0,
                  2,
                  Icons.favorite_rounded,
                  AsliColors.accentCoral,
                ),
                _breakdownTile(
                  "Likes Received",
                  breakdown['likes_received'] ?? 0,
                  3,
                  Icons.thumb_up_rounded,
                  AsliColors.accentAmber,
                ),
                _breakdownTile(
                  "Poll Votes",
                  breakdown['poll_votes'] ?? 0,
                  2,
                  Icons.poll_rounded,
                  AsliColors.accentSage,
                ),
                _breakdownTile(
                  "Stories",
                  breakdown['stories'] ?? 0,
                  8,
                  Icons.auto_stories_rounded,
                  AsliColors.accentPlum,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _breakdownTile(
    String label,
    int count,
    int pts,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: context.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            "$count × ${pts}pts = ",
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
          Text(
            "${count * pts}",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showPointsInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text("🏆 ", style: TextStyle(fontSize: 22)),
            Text(
              "How Points Work",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow("Post in CollX", "10 pts"),
            _infoRow("Reply to a post", "5 pts"),
            _infoRow("Give a like", "2 pts"),
            _infoRow("Receive a like", "3 pts"),
            _infoRow("Vote in a poll", "2 pts"),
            _infoRow("Post a story", "8 pts"),
            const Divider(height: 24),
            Text(
              "Badges",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _badgeRow("🌱", "Newcomer", "0+ pts"),
            _badgeRow("", "Active", "20+ pts"),
            _badgeRow("🔥", "Contributor", "50+ pts"),
            _badgeRow("⭐", "Star", "100+ pts"),
            _badgeRow("👑", "Legend", "200+ pts"),
            _badgeRow("🏆", "Campus Icon", "500+ pts"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Got it!",
              style: TextStyle(color: context.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String pts) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: context.textPrimary, fontSize: 13),
          ),
          Text(
            pts,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: context.accent,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeRow(String emoji, String name, String pts) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(color: context.textPrimary, fontSize: 13),
          ),
          const Spacer(),
          Text(
            pts,
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
