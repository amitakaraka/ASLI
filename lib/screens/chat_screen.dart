import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isConnected = false;
  bool _showSuggestions = true;

  static const _quickQuestions = [
    '🏛️ About AU',
    '📋 Admissions',
    '📅 Exams & Results',
    '🏠 Hostels',
    '💼 Placements',
    '📖 Library',
    '💻 MOOCS courses',
    '📜 Certificates',
    '🎉 Centenary',
    '🔗 Important links',
  ];

  late AnimationController _dotAnimController;

  @override
  void initState() {
    super.initState();
    _dotAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _checkConnection();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _dotAnimController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    final connected = await ApiService.healthCheck();
    if (mounted) setState(() => _isConnected = connected);
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text: "Hey there! 👋 I'm **Asli**, your Andhra University assistant.\n\n"
          "Ask me about AU — admissions, exams, fees, hostels, placements, certificates, rankings & more!\n\n"
          "🎉 Celebrating AU's **Centenary Year** (1926-2026)\n\n"
          "Tap a quick topic below or type your question ",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _messageController.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _isLoading = true;
      _showSuggestions = false;
    });
    _messageController.clear();
    _scrollToBottom();

    final response = await ApiService.sendMessage(text);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response != null && response['success'] == true) {
        _messages.add(ChatMessage(
          text: response['answer'] ?? 'Sorry, I couldn\'t understand that.',
          isUser: false,
          timestamp: DateTime.now(),
          confidence: response['confidence'],
          category: response['category'],
        ));
      } else {
        _messages.add(ChatMessage(
          text: 'Hmm, I couldn\'t reach the server right now. Try again in a moment! ',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      body: Container(
        color: context.pageBg,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: GestureDetector(
                  onTap: () => _focusNode.unfocus(),
                  child: _buildMessageList(),
                ),
              ),
              if (_isLoading) _buildTypingIndicator(),
              if (_showSuggestions && _messages.length <= 1) _buildQuickReplies(),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.isDark ? AsliColors.darkSurface : AsliColors.heritageBrown,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo avatar
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(40), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Asli', style: TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.3,
                )),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      color: _isConnected ? AsliColors.statusSuccess : AsliColors.statusError,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: (_isConnected ? AsliColors.statusSuccess : AsliColors.statusError).withAlpha(120),
                        blurRadius: 6,
                      )],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isConnected ? 'Online — Ready to help' : 'Offline',
                    style: TextStyle(
                      color: Colors.white.withAlpha(180), fontSize: 12, fontWeight: FontWeight.w400,
                    ),
                  ),
                ]),
              ],
            ),
          ),
          // Clear chat
          IconButton(
            onPressed: () {
              setState(() {
                _messages.clear();
                _addWelcomeMessage();
                _showSuggestions = true;
              });
            },
            icon: Icon(Icons.delete_sweep_rounded, color: Colors.white.withAlpha(160), size: 22),
            tooltip: 'Clear chat',
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Colors.white.withAlpha(160), size: 22),
            onPressed: _checkConnection,
            tooltip: 'Check connection',
          ),
        ],
      ),
    );
  }

  // ==================== MESSAGES ====================
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildMessageBubble(_messages[i], i),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final isUser = message.isUser;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            top: 4, bottom: 4,
            left: isUser ? 50 : 0,
            right: isUser ? 0 : 50,
          ),
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Bot label
              if (!isUser && index > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 3),
                  child: Text("Asli", style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: context.accent,
                  )),
                ),
              // Bubble
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser
                      ? context.accent
                      : message.isError
                          ? (context.isDark ? AsliColors.darkCard : AsliColors.lightAsh.withAlpha(80))
                          : context.cardBg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 6),
                    bottomRight: Radius.circular(isUser ? 6 : 20),
                  ),
                  border: isUser
                      ? null
                      : Border.all(
                          color: message.isError
                              ? AsliColors.accentCoral.withAlpha(60)
                              : context.borderColor,
                          width: 0.8,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: (isUser ? context.accent : Colors.black).withAlpha(8),
                      blurRadius: 8, offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Parse simple markdown bold
                    _buildRichText(message.text, isUser, message.isError),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: isUser ? Colors.white.withAlpha(160) : context.textSecondary,
                          ),
                        ),
                        if (!isUser && message.confidence != null) ...[
                          const SizedBox(width: 8),
                          _buildConfidenceBadge(message.confidence!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRichText(String text, bool isUser, bool isError) {
    // Simple markdown bold parsing: **text** → bold
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          fontWeight: i.isOdd ? FontWeight.w700 : FontWeight.w400,
          fontSize: i.isOdd ? 15.5 : 14.5,
        ),
      ));
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: isUser
              ? Colors.white
              : isError
                  ? (context.isDark ? AsliColors.accentCoral : AsliColors.statusError)
                  : context.textPrimary,
          fontSize: 14.5,
          height: 1.45,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildConfidenceBadge(int confidence) {
    Color badgeColor;
    String label;
    if (confidence >= 70) {
      badgeColor = AsliColors.statusSuccess;
      label = 'High';
    } else if (confidence >= 40) {
      badgeColor = AsliColors.statusWarning;
      label = 'Medium';
    } else {
      badgeColor = AsliColors.statusError;
      label = 'Low';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withAlpha(60)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bolt_rounded, size: 10, color: badgeColor),
        const SizedBox(width: 2),
        Text('$confidence% $label', style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600, color: badgeColor,
        )),
      ]),
    );
  }

  // ==================== TYPING INDICATOR ====================
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 18, bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor, width: 0.8),
          ),
          child: AnimatedBuilder(
            animation: _dotAnimController,
            builder: (ctx, _) {
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Text("Asli ", style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: context.accent,
                )),
                _animDot(0), _animDot(1), _animDot(2),
              ]);
            },
          ),
        ),
      ),
    );
  }

  Widget _animDot(int index) {
    final delay = index * 0.25;
    final t = (_dotAnimController.value + delay) % 1.0;
    final scale = t < 0.5 ? 1.0 + (t * 0.8) : 1.0 + ((1.0 - t) * 0.8);
    final alpha = (150 + (t * 105)).toInt().clamp(150, 255);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 7 * scale,
      height: 7 * scale,
      decoration: BoxDecoration(
        color: context.accent.withAlpha(alpha),
        shape: BoxShape.circle,
      ),
    );
  }

  // ==================== QUICK REPLIES ====================
  Widget _buildQuickReplies() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 18, bottom: 6),
            child: Text("Quick topics", style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: context.textSecondary, letterSpacing: 0.5,
            )),
          ),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _quickQuestions.length,
              itemBuilder: (_, i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _sendMessage(_quickQuestions[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.accent.withAlpha(12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: context.accent.withAlpha(60)),
                      ),
                      child: Text(_quickQuestions[i], style: TextStyle(
                        fontSize: 13, color: context.accent, fontWeight: FontWeight.w500,
                      )),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==================== INPUT ====================
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(top: BorderSide(color: context.borderColor, width: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.inputFill,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'Ask me anything about college...',
                  hintStyle: TextStyle(color: context.textSecondary.withAlpha(150), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                style: TextStyle(color: context.textPrimary, fontSize: 14.5),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
                maxLines: null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _isLoading ? context.accent.withAlpha(80) : context.accent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: context.accent.withAlpha(40),
                  blurRadius: 8, offset: const Offset(0, 2),
                )],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour > 12 ? time.hour - 12 : time.hour;
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '${h == 0 ? 12 : h}:${time.minute.toString().padLeft(2, '0')} $ampm';
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final int? confidence;
  final String? category;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.confidence,
    this.category,
    this.isError = false,
  });
}
