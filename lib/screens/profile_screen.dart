import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';
import 'edit_profile_screen.dart';
import 'bookmarks_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'search_screen.dart';
import '../widgets/loading_shimmer.dart';
import '../theme/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isRefreshing = false;
  Timer? _statsTimer;
  
  // Animation controllers
  late AnimationController _headerAnimController;
  late Animation<double> _headerAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadProfile();
    _startStatsRefresh();
  }

  void _setupAnimations() {
    _headerAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerAnimController, curve: Curves.easeOutBack),
    );
    _headerAnimController.forward();
  }

  void _startStatsRefresh() {
    _statsTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadProfile());
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    _statsTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    
    try {
      final user = await ApiService.getMe();
      if (mounted) {
        setState(() {
          _user = user ?? ApiService.currentUser;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AsliColors.primaryMaroon;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AsliColors.primaryMaroon;
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(dateStr));
      if (diff.inDays < 1) return 'Joined today';
      if (diff.inDays < 7) return 'Joined ${diff.inDays} days ago';
      if (diff.inDays < 30) return 'Joined ${diff.inDays ~/ 7} weeks ago';
      if (diff.inDays < 365) return 'Joined ${diff.inDays ~/ 30} months ago';
      return 'Joined ${diff.inDays ~/ 365} years ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.pageBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShimmerLoading(width: 120, height: 120, borderRadius: 60),
              const SizedBox(height: 24),
              ShimmerLoading(width: 200, height: 24, borderRadius: 12),
              const SizedBox(height: 12),
              ShimmerLoading(width: 150, height: 16, borderRadius: 8),
            ],
          ),
        ),
      );
    }

    final name = _user?['name'] ?? 'Student User';
    final username = _user?['username'] ?? 'user';
    final department = _user?['department'] ?? '';
    final year = _user?['year'] ?? '';
    final bio = _user?['bio'] ?? '';
    final email = _user?['email'] ?? '';
    final profileColor = _parseColor(_user?['profile_color']);
    final joinedDate = _timeAgo(_user?['created_at']);

    return Scaffold(
      backgroundColor: context.pageBg,
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: context.accent,
        backgroundColor: context.cardBg,
        child: CustomScrollView(
          slivers: [
            // App Bar with Actions
            SliverAppBar(
              floating: true,
              backgroundColor: context.pageBg,
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                  tooltip: 'Search',
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(themeProvider: ThemeProvider()))),
                  tooltip: 'Settings',
                ),
              ],
            ),

            // Profile Header
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _headerAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        profileColor,
                        profileColor.withAlpha(180),
                        context.pageBg,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Avatar
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: profileColor.withAlpha(100),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: profileColor,
                            child: Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Name & Username
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '@$username',
                          style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            bio,
                            style: TextStyle(
                              color: Colors.white.withAlpha(220),
                              fontSize: 14,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (department.isNotEmpty || year.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(50),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withAlpha(60)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.school_rounded, size: 14, color: Colors.white.withAlpha(200)),
                              const SizedBox(width: 6),
                              Text(
                                [if (department.isNotEmpty) department, if (year.isNotEmpty) year].join(' · '),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Join Date
                      Text(
                        joinedDate,
                        style: TextStyle(
                          color: Colors.white.withAlpha(150),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Quick Actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildQuickAction(Icons.edit_rounded, 'Edit Profile', context.accent, () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => EditProfileScreen(user: _user ?? {}),
                          )).then((_) => _loadProfile());
                        })),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Account Info Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(Icons.email_outlined, 'Email', email),
                      _buildDivider(),
                      _buildInfoRow(Icons.school_outlined, 'Department', department.isEmpty ? 'Not set' : department),
                      _buildDivider(),
                      _buildInfoRow(Icons.calendar_today_outlined, 'Year', year.isEmpty ? 'Not set' : year),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Menu Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildMenuSection(context),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Logout Button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showLogoutDialog,
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.accent.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: context.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 24, color: context.borderColor.withAlpha(100));
  }

  Widget _buildMenuSection(BuildContext context) {
    final menuItems = [
      {'icon': Icons.bookmark_outline_rounded, 'title': 'Bookmarks', 'color': AsliColors.accentAmber, 'screen': 'bookmarks'},
      {'icon': Icons.settings_outlined, 'title': 'Settings', 'color': AsliColors.accentSienna, 'screen': 'settings'},
      {'icon': Icons.help_outline_rounded, 'title': 'Help & Support', 'color': context.accent, 'screen': 'help'},
      {'icon': Icons.info_outline_rounded, 'title': 'About Asli', 'color': context.textSecondary, 'screen': 'about'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: menuItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == menuItems.length - 1;

          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22),
                ),
                title: Text(
                  item['title'] as String,
                  style: TextStyle(fontWeight: FontWeight.w500, color: context.textPrimary, fontSize: 15),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: context.textSecondary, size: 20),
                onTap: () {
                  switch (item['screen']) {
                    case 'bookmarks':
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BookmarksScreen()));
                      break;
                    case 'notifications':
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                      break;
                    case 'settings':
                      Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(themeProvider: ThemeProvider())));
                      break;
                    case 'analytics':
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('📊 Analytics coming soon!'),
                          backgroundColor: context.accent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                      break;
                    case 'help':
                      _showHelpDialog();
                      break;
                    case 'about':
                      _showAboutDialog();
                      break;
                  }
                },
              ),
              if (!isLast) Divider(height: 1, indent: 72, color: context.borderColor.withAlpha(100)),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Logout', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: context.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _performLogout() {
    SocketService.instance.disconnect();
    ApiService.logout();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen(onLoginSuccess: () {})));
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Help & Support', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help? Contact us:', style: TextStyle(color: context.textPrimary)),
            const SizedBox(height: 12),
            _buildHelpItem(Icons.email_rounded, 'Email', 'support@asli-campus.com'),
            _buildHelpItem(Icons.description_rounded, 'Documentation', 'docs.asli-campus.com'),
            _buildHelpItem(Icons.bug_report_rounded, 'Report Issue', 'GitHub Issues'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: context.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.accent),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: context.textSecondary)),
          Text(value, style: TextStyle(color: context.accent, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: context.accent),
            const SizedBox(width: 8),
            Text('About Asli', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.accent.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Version 21.0.0',
                style: TextStyle(color: context.accent, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Asli is the all-in-one campus companion for Andhra University students. Built for AU\'s Centenary Year (1926–2026).',
              style: TextStyle(color: context.textPrimary, height: 1.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Features:\n• CollX Social Feed\n• Real-time Messaging\n• Campus Map\n• Events & Notifications\n• Study Groups\n• AI Chatbot',
              style: TextStyle(color: context.textSecondary, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: TextStyle(color: context.accent)),
          ),
        ],
      ),
    );
  }
}
