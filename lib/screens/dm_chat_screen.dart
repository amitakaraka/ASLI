import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

class DMChatScreen extends StatefulWidget {
  final int partnerId;
  final String partnerName;
  final String partnerColor;

  const DMChatScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
    required this.partnerColor,
  });

  @override
  State<DMChatScreen> createState() => _DMChatScreenState();
}

class _DMChatScreenState extends State<DMChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  List<dynamic> _messages = [];
  Map<String, dynamic>? _partner;
  bool _isLoading = true;
  bool _isSending = false;
  bool _partnerTyping = false;
  Timer? _refreshTimer;
  Timer? _typingTimer;
  StreamSubscription? _messageSub;
  StreamSubscription? _typingSub;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupSocketListeners();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _silentRefresh(),
    );
  }

  void _setupSocketListeners() {
    _messageSub = SocketService.instance.messageStream.listen((msg) {
      if (msg.from == widget.partnerId.toString() && mounted) {
        setState(() {
          _messages.add({
            'id': DateTime.now().millisecondsSinceEpoch,
            'sender_id': widget.partnerId,
            'content': msg.content,
            'created_at': DateTime.now().toIso8601String(),
            'is_read': false,
          });
        });
        _scrollToBottom();
      }
    });

    _typingSub = SocketService.instance.typingStream.listen((typing) {
      if (typing.conversationId == widget.partnerId.toString() && mounted) {
        setState(() => _partnerTyping = typing.isTyping);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _typingTimer?.cancel();
    _messageSub?.cancel();
    _typingSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    SocketService.instance.sendTyping(
      toUserId: widget.partnerId,
      isTyping: false,
    );
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getChatMessages(widget.partnerId);
    if (data != null && mounted) {
      setState(() {
        _messages = data['messages'] ?? [];
        _partner = data['partner'];
        _isLoading = false;
      });
      _scrollToBottom();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _silentRefresh() async {
    final data = await ApiService.getChatMessages(widget.partnerId);
    if (data != null && mounted) {
      final newMsgs = data['messages'] ?? [];
      if (newMsgs.length != _messages.length) {
        setState(() {
          _messages = newMsgs;
          _partner = data['partner'];
        });
        _scrollToBottom();
      }
    }
  }

  void _onTyping(String text) {
    SocketService.instance.sendTyping(
      toUserId: widget.partnerId,
      conversationId: widget.partnerId.toString(),
      isTyping: text.isNotEmpty,
    );
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      SocketService.instance.sendTyping(
        toUserId: widget.partnerId,
        isTyping: false,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _controller.clear();
    SocketService.instance.sendTyping(
      toUserId: widget.partnerId,
      isTyping: false,
    );

    SocketService.instance.sendPrivateMessage(
      toUserId: widget.partnerId,
      content: text,
      conversationId: widget.partnerId.toString(),
    );

    final result = await ApiService.sendDM(widget.partnerId, text);
    if (result != null && mounted) {
      setState(() {
        _messages.add(result);
        _isSending = false;
      });
      _scrollToBottom();
    } else {
      setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AsliColors.primaryMaroon;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AsliColors.primaryMaroon;
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  bool _showDateSeparator(int index) {
    if (index == 0) return true;
    final curr = DateTime.tryParse(_messages[index]['created_at'] ?? '');
    final prev = DateTime.tryParse(_messages[index - 1]['created_at'] ?? '');
    if (curr == null || prev == null) return false;
    return curr.day != prev.day || curr.month != prev.month;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (date.day == now.day &&
          date.month == now.month &&
          date.year == now.year)
        return 'Today';
      if (date.day == now.day - 1 && date.month == now.month)
        return 'Yesterday';
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${date.day} ${months[date.month - 1]}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pColor = _parseColor(widget.partnerColor);
    final myId = ApiService.currentUserId;

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: pColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: pColor.withAlpha(40), blurRadius: 6),
                ],
              ),
              child: Center(
                child: Text(
                  widget.partnerName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.partnerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _partner?['username'] != null
                      ? '@${_partner!['username']}'
                      : 'AU Student',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withAlpha(180),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: context.accent),
                  )
                : _messages.isEmpty
                ? _buildEmptyChat(pColor)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMine = msg['sender_id'] == myId;
                      return Column(
                        children: [
                          if (_showDateSeparator(index))
                            _buildDateSeparator(_formatDate(msg['created_at'])),
                          _buildBubble(msg, isMine, pColor),
                        ],
                      );
                    },
                  ),
          ),
          // Typing indicator
          if (_partnerTyping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.partnerName} is typing...',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          // Input bar
          _buildInputBar(pColor),
        ],
      ),
    );
  }

  Widget _buildEmptyChat(Color pColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: pColor.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.waving_hand_rounded, size: 36, color: pColor),
          ),
          const SizedBox(height: 16),
          Text(
            "Say hi to ${widget.partnerName}!",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Start a conversation",
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: context.borderColor, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              date,
              style: TextStyle(
                fontSize: 11,
                color: context.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: context.borderColor, height: 1)),
        ],
      ),
    );
  }

  Widget _buildInputBar(Color pColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
      decoration: BoxDecoration(
        color: context.surfaceBg,
        boxShadow: [
          BoxShadow(
            color: (context.isDark ? Colors.black : AsliColors.heritageBrown)
                .withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.borderColor),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: context.textSecondary,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onChanged: _onTyping,
                  onSubmitted: (_) => _sendMessage(),
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.accent, context.accent.withAlpha(200)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.accent.withAlpha(40),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(
    Map<String, dynamic> msg,
    bool isMine,
    Color partnerColor,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            bottom: 6,
            left: isMine ? 60 : 0,
            right: isMine ? 0 : 60,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMine ? context.accent : context.cardBg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 18),
            ),
            border: isMine
                ? null
                : Border.all(color: context.borderColor, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: (isMine ? context.accent : Colors.black).withAlpha(8),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                msg['content'] ?? '',
                style: TextStyle(
                  fontSize: 14.5,
                  color: isMine ? Colors.white : context.textPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(msg['created_at']),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMine
                          ? Colors.white.withAlpha(180)
                          : context.textSecondary,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 3),
                    Icon(
                      msg['is_read'] == true
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 13,
                      color: msg['is_read'] == true
                          ? AsliColors.accentTerracotta
                          : Colors.white.withAlpha(150),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
