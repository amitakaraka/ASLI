import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

class GroupChatScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  final String groupEmoji;
  final String groupColor;
  final int memberCount;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.groupEmoji,
    required this.groupColor,
    required this.memberCount,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _refreshTimer;

  Color get _groupColor {
    try { return Color(int.parse(widget.groupColor.replaceFirst('#', '0xFF'))); }
    catch (_) { return AsliColors.primaryMaroon; }
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getGroupMessages(widget.groupId);
    if (data != null && mounted) {
      setState(() { _messages = data['messages'] ?? []; _isLoading = false; });
      _scrollToBottom();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _silentRefresh() async {
    final data = await ApiService.getGroupMessages(widget.groupId);
    if (data != null && mounted) {
      final newMsgs = data['messages'] ?? [];
      if (newMsgs.length != _messages.length) {
        setState(() => _messages = newMsgs);
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _controller.clear();
    final result = await ApiService.sendGroupMessage(widget.groupId, text);
    if (result != null && mounted) {
      _loadMessages();
    }
    if (mounted) setState(() => _isSending = false);
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final m = date.minute.toString().padLeft(2, '0');
      final p = date.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $p';
    } catch (_) { return ''; }
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AsliColors.primaryMaroon;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return AsliColors.primaryMaroon; }
  }

  void _showMembers() async {
    final detail = await ApiService.getStudyGroupDetail(widget.groupId);
    if (detail == null || !mounted) return;
    final members = detail['members'] ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        decoration: BoxDecoration(
          color: context.surfaceBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text("Members (${members.length})", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: members.length,
                itemBuilder: (_, i) {
                  final m = members[i];
                  final c = _parseColor(m['profile_color']);
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: c, child: Text(
                      (m['name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    )),
                    title: Text(m['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: context.textPrimary)),
                    subtitle: Text('@${m['username'] ?? ''} · ${m['department'] ?? ''}',
                      style: TextStyle(fontSize: 12, color: context.textSecondary)),
                    trailing: m['role'] == 'admin'
                      ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: _groupColor.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                          child: Text('Admin', style: TextStyle(fontSize: 11, color: _groupColor, fontWeight: FontWeight.bold)))
                      : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = ApiService.currentUser?['id'];

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _groupColor.withAlpha(25), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(widget.groupEmoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.groupName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('${widget.memberCount} members', style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(180))),
          ])),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.group_rounded), tooltip: 'Members', onPressed: _showMembers),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _isLoading
              ? Center(child: CircularProgressIndicator(color: context.accent))
              : _messages.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(widget.groupEmoji, style: const TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text("No messages yet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textSecondary)),
                    const SizedBox(height: 6),
                    Text("Be the first to send a message!", style: TextStyle(fontSize: 13, color: context.textSecondary)),
                  ]))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildMessage(_messages[i], myId, i),
                  ),
          ),
          // Input bar
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
                      focusNode: _focusNode,
                      maxLines: 4,
                      minLines: 1,
                      style: TextStyle(color: context.textPrimary, fontSize: 15),
                      decoration: InputDecoration(hintText: 'Type a message...', hintStyle: TextStyle(color: context.textSecondary), border: InputBorder.none),
                      onSubmitted: (_) => _sendMessage(),
                    )),
                    const SizedBox(width: 8),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(color: context.accent, shape: BoxShape.circle),
                child: IconButton(
                  icon: _isSending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg, int? myId, int index) {
    final isMe = msg['sender_id'] == myId;
    final isSystem = msg['message_type'] == 'system';

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(8)),
          child: Text(msg['content'] ?? '', style: TextStyle(fontSize: 12, color: context.textSecondary, fontStyle: FontStyle.italic)),
        )),
      );
    }

    // Show sender name if different from previous
    bool showSender = !isMe;
    if (index > 0 && !isMe) {
      final prev = _messages[index - 1];
      if (prev['sender_id'] == msg['sender_id'] && prev['message_type'] != 'system') showSender = false;
    }

    final senderColor = _parseColor(msg['sender_color']);

    return Padding(
      padding: EdgeInsets.only(bottom: 4, top: showSender ? 8 : 0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showSender)
            CircleAvatar(radius: 14, backgroundColor: senderColor, child: Text(
              (msg['sender_name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ))
          else if (!isMe)
            const SizedBox(width: 28),
          const SizedBox(width: 6),
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              decoration: BoxDecoration(
                color: isMe ? context.accent : context.cardBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isMe ? null : Border.all(color: context.borderColor),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (showSender && !isMe)
                  Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(
                    msg['sender_name'] ?? 'Unknown',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: senderColor),
                  )),
                Text(msg['content'] ?? '', style: TextStyle(fontSize: 15, color: isMe ? Colors.white : context.textPrimary, height: 1.3)),
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(_formatTime(msg['created_at']), style: TextStyle(fontSize: 10, color: isMe ? Colors.white.withAlpha(180) : context.textSecondary)),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
