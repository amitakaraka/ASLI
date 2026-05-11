import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _overview;
  List<dynamic> _users = [];
  List<dynamic> _auditLog = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAdminAccess();
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getAdminOverview(),
        ApiService.getAdminUsers(),
        ApiService.getAuditLog(),
      ]);
      if (mounted) {
        setState(() {
          _overview = results[0] as Map<String, dynamic>?;
          _users = results[1] as List<dynamic>;
          _auditLog = results[2] as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading admin data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleUserStatus(int userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Action'),
        content: Text('Are you sure you want to change the status of $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await ApiService.toggleUserStatus(userId);
      if (mounted) {
        if (result != null && result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'User status updated'),
              backgroundColor: Colors.green,
            ),
          );
          _loadAllData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result?['error'] ?? 'Failed to update user'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  Future<void> _checkAdminAccess() async {
    final user = ApiService.currentUser;
    if (user == null || !(user['is_admin'] == true)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin access required'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text("Admin Panel", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          // Admin badge
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.accent.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.accent.withAlpha(60)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  'ADMIN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _isLoading ? null : _loadAllData,
            tooltip: 'Refresh data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.white.withAlpha(180)),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 16), text: 'Overview'),
            Tab(icon: Icon(Icons.people_rounded, size: 16), text: 'Users'),
            Tab(icon: Icon(Icons.history_rounded, size: 16), text: 'Activity'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.accent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildUsersTab(),
                _buildActivityTab(),
              ],
            ),
    );
  }

  // ====== OVERVIEW TAB ======
  Widget _buildOverviewTab() {
    if (_overview == null) return const Center(child: Text("No data"));

    final users = _overview!['users'] ?? {};
    final content = _overview!['content'] ?? {};
    final social = _overview!['social'] ?? {};
    final depts = _overview!['departments'] as List? ?? [];
    final topContribs = _overview!['top_contributors'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Row
          Row(
            children: [
              _kpiCard('👥', '${users['total'] ?? 0}', 'Users', AsliColors.accentIndigo),
              const SizedBox(width: 10),
              _kpiCard('📝', '${content['posts'] ?? 0}', 'Posts', AsliColors.accentCoral),
              const SizedBox(width: 10),
              _kpiCard('', '${social['dms'] ?? 0}', 'DMs', AsliColors.accentTeal),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _kpiCard('❤️', '${content['likes'] ?? 0}', 'Likes', AsliColors.accentAmber),
              const SizedBox(width: 10),
              _kpiCard('❓', '${content['questions'] ?? 0}', 'Questions', AsliColors.accentPlum),
              const SizedBox(width: 10),
              _kpiCard('', '${social['notifications'] ?? 0}', 'Notifs', AsliColors.accentSlate),
            ],
          ),
          const SizedBox(height: 20),

          // User Status
          _sectionTitle('User Status'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statusCircle(users['active'] ?? 0, 'Active', AsliColors.statusSuccess),
                _statusCircle(users['inactive'] ?? 0, 'Inactive', Colors.red),
                _statusCircle(users['total'] ?? 0, 'Total', context.accent),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Department Breakdown
          _sectionTitle('Departments'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              children: depts.map<Widget>((d) {
                final pct = (users['total'] ?? 1) > 0
                    ? (d['count'] as int) / (users['total'] as int)
                    : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(d['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.textPrimary)),
                          Text('${d['count']} users', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: context.borderColor,
                          valueColor: AlwaysStoppedAnimation(context.accent),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Top Contributors
          _sectionTitle('Top Contributors'),
          ...topContribs.map((c) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _parseColor(c['color']),
                  child: Text((c['name'] ?? 'U')[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.textPrimary)),
                      Text('@${c['username']}', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.accent.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${c['posts']} posts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.accent)),
                ),
              ],
            ),
          )),
          const SizedBox(height: 20),

          // Content Stats
          _sectionTitle('Content Breakdown'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              children: [
                _contentRow('Posts', content['posts'] ?? 0, Icons.article_rounded, AsliColors.accentIndigo),
                _contentRow('Replies', content['replies'] ?? 0, Icons.reply_rounded, AsliColors.accentCoral),
                _contentRow('Likes', content['likes'] ?? 0, Icons.favorite_rounded, AsliColors.accentAmber),
                _contentRow('Questions', content['questions'] ?? 0, Icons.help_rounded, AsliColors.accentPlum),
                _contentRow('Answers', content['answers'] ?? 0, Icons.check_circle_rounded, AsliColors.accentTeal),
                _contentRow('DMs', social['dms'] ?? 0, Icons.mail_rounded, AsliColors.accentSlate),
                _contentRow('Follows', social['follows'] ?? 0, Icons.people_rounded, context.accent),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ====== USERS TAB ======
  Widget _buildUsersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final u = _users[index];
        final color = _parseColor(u['profile_color']);
        final isActive = u['is_active'] ?? true;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isActive ? context.borderColor : Colors.red.withAlpha(50)),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: isActive ? color : Colors.grey,
                    child: Text((u['name'] ?? 'U')[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        color: isActive ? AsliColors.statusSuccess : AsliColors.statusError,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.cardBg, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(u['name'] ?? '', style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15,
                          color: isActive ? context.textPrimary : Colors.grey,
                        )),
                        if (!isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: Colors.red.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                            child: const Text('BANNED', style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                    Text('@${u['username']} • ${u['department']} ${u['year']}',
                        style: TextStyle(fontSize: 12, color: context.textSecondary)),
                    Text('${u['post_count']} posts • ${u['dm_count']} DMs • ${u['follower_count']} followers',
                        style: TextStyle(fontSize: 11, color: context.textSecondary)),
                  ],
                ),
              ),
              // Toggle button
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                      color: isActive ? AsliColors.statusError : AsliColors.statusSuccess,
                    ),
                    onPressed: () => _toggleUserStatus(u['id'], u['name'] ?? 'User'),
                    tooltip: isActive ? 'Deactivate' : 'Activate',
                  ),
                  Text(isActive ? 'Ban' : 'Unban', style: TextStyle(
                    fontSize: 10, color: isActive ? AsliColors.statusError : AsliColors.statusSuccess,
                    fontWeight: FontWeight.w600,
                  )),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ====== ACTIVITY TAB ======
  Widget _buildActivityTab() {
    return _auditLog.isEmpty
        ? Center(child: Text("No recent activity", style: TextStyle(color: context.textSecondary)))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _auditLog.length,
            itemBuilder: (context, index) {
              final a = _auditLog[index];
              final typeColor = a['type'] == 'post' ? AsliColors.accentIndigo
                  : a['type'] == 'dm' ? AsliColors.accentTeal
                  : AsliColors.accentAmber;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(14),
                decoration: _cardDecoration(),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: typeColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(child: Text(a['icon'] ?? '📌', style: const TextStyle(fontSize: 18))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a['description'] ?? '', style: TextStyle(fontSize: 13, color: context.textPrimary, height: 1.3)),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: typeColor.withAlpha(15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(a['type'] ?? '', style: TextStyle(fontSize: 10, color: typeColor, fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 8),
                              Text(_timeAgo(a['time']), style: TextStyle(fontSize: 11, color: context.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
  }

  // ====== HELPERS ======
  Widget _kpiCard(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.cardBg,
              color.withAlpha(10),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(40)),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: context.textSecondary, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCircle(int count, String label, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withAlpha(20),
                  color.withAlpha(5),
                ],
              ),
              border: Border.all(color: color, width: 3),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(30),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contentRow(String label, int count, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(30)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 14, color: context.textPrimary, fontWeight: FontWeight.w500)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: context.cardBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(5),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: context.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
