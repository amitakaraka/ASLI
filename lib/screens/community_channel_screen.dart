import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

class CommunityChannelScreen extends StatefulWidget {
  final String channelId;
  final String channelName;
  final String channelEmoji;
  final String channelColor;
  final String channelDesc;

  const CommunityChannelScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    required this.channelEmoji,
    required this.channelColor,
    required this.channelDesc,
  });

  @override
  State<CommunityChannelScreen> createState() => _CommunityChannelScreenState();
}

class _CommunityChannelScreenState extends State<CommunityChannelScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _posts = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _refreshTimer;

  Color get _channelColor {
    try { return Color(int.parse(widget.channelColor.replaceFirst('#', '0xFF'))); }
    catch (_) { return AsliColors.primaryMaroon; }
  }

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getCommunityPosts(channel: widget.channelId);
    if (data != null && mounted) {
      setState(() { _posts = data['posts'] ?? []; _isLoading = false; });
      _scrollToBottom();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _silentRefresh() async {
    final data = await ApiService.getCommunityPosts(channel: widget.channelId);
    if (data != null && mounted) {
      final newPosts = data['posts'] ?? [];
      if (newPosts.length != _posts.length) {
        setState(() => _posts = newPosts);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendPost() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _controller.clear();
    final result = await ApiService.postToCommunity(widget.channelId, text);
    if (result != null && mounted) _loadPosts();
    if (mounted) setState(() => _isSending = false);
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final m = date.minute.toString().padLeft(2, '0');
      final p = date.hour >= 12 ? 'PM' : 'AM';
      if (diff.inDays == 0) return '$h:$m $p';
      if (diff.inDays == 1) return 'Yesterday $h:$m $p';
      return '${date.day}/${date.month} $h:$m $p';
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
        titleSpacing: 0,
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _channelColor.withAlpha(25), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(widget.channelEmoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.campaign_rounded, size: 14, color: Colors.white.withAlpha(200)),
              const SizedBox(width: 4),
              Text(widget.channelName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            Text(widget.channelDesc, style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(160)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
      body: Column(
        children: [
          // Channel info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: _channelColor.withAlpha(10),
            child: Row(children: [
              Icon(Icons.lock_open_rounded, size: 14, color: _channelColor),
              const SizedBox(width: 8),
              Expanded(child: Text(
                "This is a community channel. All campus members can view and post.",
                style: TextStyle(fontSize: 11, color: context.textSecondary),
              )),
            ]),
          ),
          // Posts
          Expanded(
            child: _isLoading
              ? Center(child: CircularProgressIndicator(color: context.accent))
              : _posts.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(widget.channelEmoji, style: const TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text("No posts in this channel yet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textSecondary)),
                    const SizedBox(height: 6),
                    Text("Be the first to post!", style: TextStyle(fontSize: 13, color: context.textSecondary)),
                  ]))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: _posts.length,
                    itemBuilder: (_, i) => _buildPostBubble(_posts[i]),
                  ),
          ),
          // Input
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
            decoration: BoxDecoration(
              color: context.surfaceBg,
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: Row(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(24), border: Border.all(color: context.borderColor)),
                  child: Row(children: [
                    const SizedBox(width: 14),
                    Expanded(child: TextField(
                      controller: _controller,
                      maxLines: 4,
                      minLines: 1,
                      style: TextStyle(color: context.textPrimary, fontSize: 15),
                      decoration: InputDecoration(hintText: 'Post to ${widget.channelName}...', hintStyle: TextStyle(color: context.textSecondary), border: InputBorder.none),
                      onSubmitted: (_) => _sendPost(),
                    )),
                    const SizedBox(width: 8),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(color: _channelColor, shape: BoxShape.circle),
                child: IconButton(
                  icon: _isSending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: _sendPost,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildPostBubble(Map<String, dynamic> post) {
    final authorColor = _parseColor(post['author_color']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Author row
          Row(children: [
            CircleAvatar(radius: 16, backgroundColor: authorColor, child: Text(
              (post['author_name'] ?? 'U')[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            )),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post['author_name'] ?? 'Unknown', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: authorColor)),
              Text(_formatTime(post['created_at']), style: TextStyle(fontSize: 11, color: context.textSecondary)),
            ])),
          ]),
          const SizedBox(height: 8),
          // Content
          Text(post['content'] ?? '', style: TextStyle(fontSize: 15, color: context.textPrimary, height: 1.4)),
        ]),
      ),
    );
  }
}
