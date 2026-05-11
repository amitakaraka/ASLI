import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';
import 'dm_chat_screen.dart';
import 'group_chat_screen.dart';
import 'community_channel_screen.dart';
import 'search_screen.dart';
import 'study_groups_screen.dart';

import 'polls_screen.dart';
import 'events_screen.dart';

/// WhatsApp-style unified messaging hub with 3 tabs: Chats | Groups | Community
class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _refreshTimer;

  // Data
  List<dynamic> _conversations = [];
  List<dynamic> _myGroups = [];
  List<dynamic> _channels = [];
  bool _loadingChats = true;
  bool _loadingGroups = true;
  bool _loadingCommunity = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() { if (mounted) setState(() {}); });
    _loadAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadChats();
    _loadGroups();
    _loadCommunity();
  }

  Future<void> _loadChats() async {
    setState(() => _loadingChats = true);
    final data = await ApiService.getConversations();
    if (mounted) setState(() { _conversations = data; _loadingChats = false; });
  }

  Future<void> _loadGroups() async {
    setState(() => _loadingGroups = true);
    final data = await ApiService.getMyStudyGroups();
    if (mounted) setState(() { _myGroups = data ?? []; _loadingGroups = false; });
  }

  // Default community channels
  static const List<Map<String, dynamic>> _defaultChannels = [
    {
      'id': -1,
      'name': 'Andhra University Official',
      'emoji': '🏛️',
      'color': '#8B1A1A',
      'desc': 'Official updates from Andhra University administration',
      'member_count': 2400,
    },
    {
      'id': -2,
      'name': 'AU College of Engineering',
      'emoji': '⚙️',
      'color': '#1E3A5F',
      'desc': 'Engineering college announcements & discussions',
      'member_count': 1200,
    },
    {
      'id': -3,
      'name': 'Dept of CSE',
      'emoji': '💻',
      'color': '#2E7D32',
      'desc': 'Computer Science & Engineering department updates',
      'member_count': 380,
    },
  ];

  Future<void> _loadCommunity() async {
    setState(() => _loadingCommunity = true);
    final data = await ApiService.getCommunityChannels();
    if (mounted) {
      final apiChannels = data ?? [];
      // Merge default channels with API channels (avoid duplicates by id)
      final apiIds = apiChannels.map((c) => c['id']).toSet();
      final defaults = _defaultChannels.where((c) => !apiIds.contains(c['id'])).toList();
      setState(() { _channels = [...defaults, ...apiChannels]; _loadingCommunity = false; });
    }
  }

  Future<void> _silentRefresh() async {
    final chats = await ApiService.getConversations();
    if (mounted && chats.isNotEmpty) setState(() => _conversations = chats);
    final groups = await ApiService.getMyStudyGroups();
    if (mounted && groups != null) setState(() => _myGroups = groups);
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(dateStr));
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${(diff.inDays / 7).floor()}w';
    } catch (_) { return ''; }
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AsliColors.primaryMaroon;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return AsliColors.primaryMaroon; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: const Text("Messages", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(icon: const Icon(Icons.search_rounded, size: 22), tooltip: 'Search',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              if (v == 'new_group') _navigateToNewGroup();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'new_group', child: Row(children: [
                Icon(Icons.group_add_rounded, size: 20), SizedBox(width: 10), Text("New group"),
              ])),
              const PopupMenuItem(value: 'settings', child: Row(children: [
                Icon(Icons.settings_rounded, size: 20), SizedBox(width: 10), Text("Settings"),
              ])),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorWeight: 3,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: [
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text("Chats"),
              if (_totalUnread > 0) ...[
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Text('$_totalUnread', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.accent))),
              ],
            ])),
            const Tab(text: "Groups"),
            const Tab(text: "Community"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatsTab(),
          _buildGroupsTab(),
          _buildCommunityTab(),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  int get _totalUnread => _conversations.fold(0, (sum, c) => sum + ((c['unread_count'] ?? 0) as int));

  Widget? _buildFAB() {
    final tabIndex = _tabController.index;
    if (tabIndex == 0) {
      return FloatingActionButton(
        backgroundColor: context.accent,
        onPressed: _showNewDMPicker,
        child: const Icon(Icons.chat_rounded, color: Colors.white),
      );
    } else if (tabIndex == 1) {
      return FloatingActionButton(
        backgroundColor: context.accent,
        onPressed: _navigateToNewGroup,
        child: const Icon(Icons.group_add_rounded, color: Colors.white),
      );
    }
    return null;
  }

  void _navigateToNewGroup() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyGroupsScreen()));
    _loadGroups();
  }

  void _showNewDMPicker() async {
    // Use search to find a user, then open DM chat
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewDMPickerSheet(),
    );
    if (result != null && mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => DMChatScreen(
        partnerId: result['id'], partnerName: result['name'] ?? 'User', partnerColor: result['profile_color'] ?? '#A9523C',
      )));
      _loadChats();
    }
  }

  // CHATS TAB (1-on-1 DMs)
  Widget _buildChatsTab() {
    if (_loadingChats) return Center(child: CircularProgressIndicator(color: context.accent));
    if (_conversations.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.chat_bubble_outline_rounded, size: 64, color: context.borderColor),
        const SizedBox(height: 16),
        Text("No conversations yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.textSecondary)),
        const SizedBox(height: 8),
        Text("Start chatting from someone's profile", style: TextStyle(fontSize: 13, color: context.textSecondary)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _loadChats,
      color: context.accent,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4),
        itemCount: _conversations.length,
        itemBuilder: (_, i) => _buildChatTile(_conversations[i]),
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> convo) {
    final unread = convo['unread_count'] ?? 0;
    final color = _parseColor(convo['partner_color']);

    return InkWell(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => DMChatScreen(
          partnerId: convo['partner_id'], partnerName: convo['partner_name'] ?? 'User', partnerColor: convo['partner_color'] ?? '#A9523C',
        )));
        _loadChats();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: unread > 0 ? context.accent.withAlpha(context.isDark ? 12 : 6) : Colors.transparent,
          border: Border(bottom: BorderSide(color: context.borderColor.withAlpha(60), width: 0.5)),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(radius: 26, backgroundColor: color, child: Text(
                  (convo['partner_name'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                )),
                Positioned(bottom: 0, right: 0, child: Container(width: 14, height: 14,
                  decoration: BoxDecoration(color: AsliColors.statusSuccess, shape: BoxShape.circle, border: Border.all(color: context.cardBg, width: 2)),
                )),
              ],
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(convo['partner_name'] ?? 'Unknown',
                    style: TextStyle(fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600, fontSize: 16, color: context.textPrimary))),
                  Text(_timeAgo(convo['last_time']),
                    style: TextStyle(fontSize: 12, color: unread > 0 ? context.accent : context.textSecondary, fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  if (convo['is_sender'] == true)
                    Icon(Icons.done_all_rounded, size: 16, color: AsliColors.accentTeal),
                  if (convo['is_sender'] == true) const SizedBox(width: 4),
                  Expanded(child: Text(convo['last_message'] ?? '', style: TextStyle(
                    fontSize: 14, color: unread > 0 ? context.textPrimary : context.textSecondary,
                    fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
                  ), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (unread > 0) ...[
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: context.accent, borderRadius: BorderRadius.circular(12)),
                      child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  ],
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // GROUPS TAB (Study Group Chats)
  Widget _buildGroupsTab() {
    if (_loadingGroups) return Center(child: CircularProgressIndicator(color: context.accent));
    if (_myGroups.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.groups_rounded, size: 64, color: context.borderColor),
        const SizedBox(height: 16),
        Text("No groups yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.textSecondary)),
        const SizedBox(height: 8),
        Text("Join or create a study group to start chatting", style: TextStyle(fontSize: 13, color: context.textSecondary)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.explore_rounded),
          label: const Text("Browse Groups"),
          style: ElevatedButton.styleFrom(backgroundColor: context.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: _navigateToNewGroup,
        ),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _loadGroups,
      color: context.accent,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4),
        itemCount: _myGroups.length,
        itemBuilder: (_, i) => _buildGroupTile(_myGroups[i]),
      ),
    );
  }

  Widget _buildGroupTile(Map<String, dynamic> group) {
    final color = _parseColor(group['color']);
    final emoji = group['emoji'] ?? '📚';
    final members = group['member_count'] ?? 0;

    return InkWell(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatScreen(
          groupId: group['id'], groupName: group['name'] ?? 'Group', groupEmoji: emoji, groupColor: group['color'] ?? '#3B82F6', memberCount: members,
        )));
        _loadGroups();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.borderColor.withAlpha(60), width: 0.5))),
        child: Row(
          children: [
            // Group avatar
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(16)),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(group['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.textPrimary))),
                  Text(_timeAgo(group['last_message_time']), style: TextStyle(fontSize: 12, color: context.textSecondary)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.group_rounded, size: 14, color: context.textSecondary),
                  const SizedBox(width: 4),
                  Text('$members', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    group['last_message_sender'] != null && (group['last_message_sender'] as String).isNotEmpty
                      ? '${group['last_message_sender']}: ${group['last_message'] ?? ''}'
                      : group['subject'] ?? '',
                    style: TextStyle(fontSize: 13, color: context.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis,
                  )),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // COMMUNITY TAB (Broadcast Channels)
  Widget _buildCommunityTab() {
    if (_loadingCommunity) return Center(child: CircularProgressIndicator(color: context.accent));

    return RefreshIndicator(
      onRefresh: _loadCommunity,
      color: context.accent,
      child: ListView(
        padding: const EdgeInsets.only(top: 8),
        children: [


          // ─── Polls Feature Card ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PollsScreen())),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AsliColors.accentTeal,
                      AsliColors.accentTeal.withAlpha(180),
                      AsliColors.accentIndigo.withAlpha(200),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AsliColors.accentTeal.withAlpha(40),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -15, top: -15,
                      child: Icon(Icons.how_to_vote_rounded, size: 110, color: Colors.white.withAlpha(15)),
                    ),
                    Positioned(
                      left: -10, bottom: -10,
                      child: Icon(Icons.bar_chart_rounded, size: 80, color: Colors.white.withAlpha(10)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withAlpha(40)),
                            ),
                            child: const Center(child: Text("📊", style: TextStyle(fontSize: 28))),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Polls",
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Vote · Create polls · See results 📈",
                                  style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(200), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: Colors.white.withAlpha(25), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Quick Create Poll Button ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: OutlinedButton.icon(
              onPressed: () => _showQuickPollDialog(),
              icon: Icon(Icons.add_chart_rounded, color: AsliColors.accentTeal, size: 20),
              label: Text(
                "Create a quick poll...",
                style: TextStyle(color: context.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: context.borderColor),
                backgroundColor: context.cardBg,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Events Feature Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventsScreen())),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AsliColors.accentAmber,
                      AsliColors.accentAmber.withAlpha(180),
                      AsliColors.accentCoral.withAlpha(200),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AsliColors.accentAmber.withAlpha(40),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -15, top: -15,
                      child: Icon(Icons.event_rounded, size: 110, color: Colors.white.withAlpha(15)),
                    ),
                    Positioned(
                      left: -10, bottom: -10,
                      child: Icon(Icons.calendar_month_rounded, size: 80, color: Colors.white.withAlpha(10)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withAlpha(40)),
                            ),
                            child: const Center(child: Text("📅", style: TextStyle(fontSize: 28))),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Events",
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Campus events · Fests · Workshops · RSVP",
                                  style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(200), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: Colors.white.withAlpha(25), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),


          const SizedBox(height: 12),

          // ─── Community Channels Header ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: context.accent.withAlpha(15), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.campaign_rounded, color: context.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("AU Community", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary)),
                Text("Campus-wide channels for all students", style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ])),
            ]),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: context.borderColor.withAlpha(60)),

          // ─── Channels ───
          if (_channels.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.campaign_rounded, size: 48, color: context.borderColor),
                const SizedBox(height: 12),
                Text("No channels yet", style: TextStyle(fontSize: 15, color: context.textSecondary)),
              ])),
            )
          else
            ..._channels.map((ch) => _buildChannelTile(ch)),
        ],
      ),
    );
  }




  void _showQuickPollDialog() {
    final questionCtrl = TextEditingController();
    final optionControllers = [TextEditingController(), TextEditingController()];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: BoxDecoration(
            color: context.surfaceBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 16),
                // Title
                Row(children: [
                  const Text("📊", style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Text("Create Poll", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
                ]),
                const SizedBox(height: 4),
                Text("Ask the campus what they think! 🗳️", style: TextStyle(fontSize: 13, color: context.textSecondary)),
                const SizedBox(height: 16),
                // Question input
                TextField(
                  controller: questionCtrl,
                  autofocus: true,
                  style: TextStyle(color: context.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: "Ask a question...",
                    hintStyle: TextStyle(color: context.textSecondary),
                    filled: true,
                    fillColor: context.cardBg,
                    prefixIcon: Icon(Icons.help_outline_rounded, color: AsliColors.accentTeal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.borderColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AsliColors.accentTeal, width: 2)),
                  ),
                ),
                const SizedBox(height: 12),
                // Options
                Text("Options", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
                const SizedBox(height: 8),
                ...optionControllers.asMap().entries.map((entry) {
                  final i = entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AsliColors.accentTeal.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AsliColors.accentTeal))),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: entry.value,
                            style: TextStyle(color: context.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: "Option ${i + 1}",
                              hintStyle: TextStyle(color: context.textSecondary),
                              filled: true,
                              fillColor: context.cardBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AsliColors.accentTeal, width: 1.5)),
                            ),
                          ),
                        ),
                        if (i >= 2)
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline, color: Colors.red.withAlpha(180), size: 20),
                            onPressed: () => setModalState(() => optionControllers.removeAt(i)),
                          ),
                      ],
                    ),
                  );
                }),
                // Add option button
                if (optionControllers.length < 6)
                  TextButton.icon(
                    onPressed: () => setModalState(() => optionControllers.add(TextEditingController())),
                    icon: Icon(Icons.add_rounded, color: AsliColors.accentTeal, size: 18),
                    label: Text("Add option", style: TextStyle(color: AsliColors.accentTeal, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 12),
                // Submit
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final q = questionCtrl.text.trim();
                      final opts = optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                      if (q.isEmpty || opts.length < 2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Need a question and at least 2 options")),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      await ApiService.createPoll(q, opts);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Poll created! 📊")),
                        );
                      }
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text("Create Poll", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AsliColors.accentTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelTile(Map<String, dynamic> channel) {
    final color = _parseColor(channel['color']);
    final emoji = channel['emoji'] ?? '';

    return InkWell(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => CommunityChannelScreen(
          channelId: channel['id'], channelName: channel['name'] ?? 'Channel', channelEmoji: emoji, channelColor: channel['color'] ?? '#3B82F6', channelDesc: channel['desc'] ?? '',
        )));
        _loadCommunity();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.borderColor.withAlpha(60), width: 0.5))),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(16)),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.campaign_rounded, size: 14, color: color),
                  const SizedBox(width: 4),
                  Expanded(child: Text(channel['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.textPrimary))),
                  Text(_timeAgo(channel['last_post_time']), style: TextStyle(fontSize: 12, color: context.textSecondary)),
                ]),
                const SizedBox(height: 4),
                Text(
                  channel['last_post_author'] != null && (channel['last_post_author'] as String).isNotEmpty
                    ? '${channel['last_post_author']}: ${channel['last_post'] ?? ''}'
                    : channel['desc'] ?? '',
                  style: TextStyle(fontSize: 13, color: context.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for picking a user to start a new DM
class _NewDMPickerSheet extends StatefulWidget {
  @override
  State<_NewDMPickerSheet> createState() => _NewDMPickerSheetState();
}

class _NewDMPickerSheetState extends State<_NewDMPickerSheet> {
  final _controller = TextEditingController();
  List<dynamic> _users = [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (q.length < 2) { setState(() => _users = []); return; }
      setState(() => _searching = true);
      final result = await ApiService.searchCollx(q);
      if (mounted && result != null) {
        setState(() { _users = result['users'] ?? []; _searching = false; });
      } else {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AsliColors.primaryMaroon;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return AsliColors.primaryMaroon; }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: context.surfaceBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text("New Message", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by name or username...',
                hintStyle: TextStyle(color: context.textSecondary),
                prefixIcon: Icon(Icons.search_rounded, color: context.textSecondary),
                filled: true, fillColor: context.cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.borderColor)),
              ),
              onChanged: _onSearch,
            ),
          ),
          const SizedBox(height: 8),
          if (_searching) Padding(padding: const EdgeInsets.all(20), child: CircularProgressIndicator(color: context.accent)),
          Expanded(
            child: _users.isEmpty
              ? Center(child: Text(_controller.text.length < 2 ? "Type to search users" : "No users found",
                  style: TextStyle(color: context.textSecondary)))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (_, i) {
                    final u = _users[i];
                    final c = _parseColor(u['profile_color']);
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: c, child: Text(
                        (u['name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )),
                      title: Text(u['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: context.textPrimary)),
                      subtitle: Text('@${u['username'] ?? ''} · ${u['department'] ?? ''}',
                        style: TextStyle(fontSize: 12, color: context.textSecondary)),
                      onTap: () => Navigator.pop(context, u),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
