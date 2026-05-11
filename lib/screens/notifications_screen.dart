import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';
import 'user_profile_screen.dart';
import 'collx_post_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    // Auto-refresh every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getNotifications();
    if (data != null && mounted) {
      setState(() {
        _notifications = data['data'] ?? [];
        _unreadCount = data['unread_count'] ?? 0;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  /// Silent refresh — no loading spinner, only updates if count changed
  Future<void> _silentRefresh() async {
    final data = await ApiService.getNotifications();
    if (data != null && mounted) {
      final newList = data['data'] ?? [];
      final newUnread = data['unread_count'] ?? 0;
      if (newList.length != _notifications.length || newUnread != _unreadCount) {
        setState(() {
          _notifications = newList;
          _unreadCount = newUnread;
        });
      }
    }
  }

  Future<void> _markAllRead() async {
    await ApiService.markAllNotificationsRead();
    setState(() {
      _unreadCount = 0;
      for (var n in _notifications) {
        n['is_read'] = true;
      }
    });
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'like': return Icons.favorite_rounded;
      case 'reply': return Icons.reply_rounded;
      case 'follow': return Icons.person_add_rounded;
      case 'system': return Icons.campaign_rounded;
      case 'mention': return Icons.alternate_email_rounded;
      case 'event': return Icons.event_rounded;
      case 'answer': return Icons.question_answer_rounded;
      case 'dm': return Icons.mail_rounded;
      case 'marketplace': return Icons.shopping_bag_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'like': return AsliColors.accentCoral;
      case 'reply': return AsliColors.accentTeal;
      case 'follow': return AsliColors.accentSage;
      case 'system': return AsliColors.accentAmber;
      case 'mention': return AsliColors.accentIndigo;
      case 'event': return AsliColors.statusInfo;
      case 'answer': return AsliColors.accentPlum;
      case 'dm': return AsliColors.accentSlate;
      case 'marketplace': return AsliColors.accentSienna;
      default: return AsliColors.stoneBrown;
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: Row(
          children: [
            const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(60),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all_rounded, color: Colors.white, size: 18),
              label: const Text("Read All", style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.accent))
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: context.accent,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) => _buildNotifTile(_notifications[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 64, color: context.borderColor),
          const SizedBox(height: 16),
          Text(
            "No notifications yet",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            "When someone interacts with your posts,\nyou'll see it here!",
            style: TextStyle(fontSize: 13, color: context.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotifTile(Map<String, dynamic> notif) {
    final isUnread = notif['is_read'] != true;
    final type = notif['type'] ?? 'system';
    final iconColor = _getIconColor(type);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isUnread
            ? context.accent.withAlpha(context.isDark ? 15 : 8)
            : context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnread
              ? context.accent.withAlpha(context.isDark ? 40 : 30)
              : context.borderColor,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Stack(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(context.isDark ? 30 : 20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getIcon(type), color: iconColor, size: 22),
            ),
            if (isUnread)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: context.accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.cardBg,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          notif['title'] ?? '',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
            color: context.textPrimary,
          ),
        ),
        subtitle: notif['body']?.isNotEmpty == true
            ? Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  notif['body'],
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : null,
        trailing: Text(
          _timeAgo(notif['created_at']),
          style: TextStyle(
            fontSize: 11,
            color: isUnread ? context.accent : context.textSecondary,
            fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () async {
          if (isUnread) {
            await ApiService.markNotificationRead(notif['id']);
            setState(() {
              notif['is_read'] = true;
              _unreadCount = (_unreadCount - 1).clamp(0, 9999);
            });
          }
          // Navigate based on type
          if (!mounted) return;
          final targetId = notif['target_id'];
          if (targetId == null) return;
          if (type == 'follow') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: targetId)));
          } else if (type == 'like' || type == 'reply' || type == 'mention') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => CollxPostDetailScreen(postId: targetId)));
          }
        },
      ),
    );
  }
}
