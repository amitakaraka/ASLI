import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';
import '../widgets/skeleton_loaders.dart';
import '../widgets/error_states.dart';
import 'answer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _questionController = TextEditingController();
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = false;
  bool _isConnected = false;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _loadQuestions();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _silentRefresh(),
    );
  }

  Future<void> _checkConnection() async {
    final connected = await ApiService.healthCheck();
    if (mounted) setState(() => _isConnected = connected);
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final questions = await ApiService.getQuestions();
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _submitQuestion() async {
    final text = _questionController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);
    final result = await ApiService.addQuestion(text);

    if (result != null) {
      _questionController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Question submitted!'),
            backgroundColor: context.accent,
          ),
        );
      }
      _loadQuestions();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit question'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(dateStr));
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  Future<void> _silentRefresh() async {
    final questions = await ApiService.getQuestions();
    if (mounted && questions.length != _questions.length) {
      setState(() => _questions = questions);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildQuestionInput(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 5,
        itemBuilder: (context, index) => const PostSkeletonLoader(),
      );
    }

    if (_hasError) {
      return NetworkErrorWidget(
        onRetry: _loadQuestions,
        message: _errorMessage,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQuestions,
      color: context.accent,
      child: _questions.isEmpty ? _buildEmptyState() : _buildQuestionsList(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.accent, context.accent.withAlpha(180)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: context.accent.withAlpha(60),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Q&A',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _isConnected
                            ? AsliColors.statusSuccess
                            : AsliColors.statusError,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isConnected ? 'Connected' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_questions.length} question${_questions.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              _checkConnection();
              _loadQuestions();
            },
            icon: Icon(Icons.refresh_rounded, color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionInput() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: (context.isDark ? Colors.black : AsliColors.heritageBrown)
                .withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _questionController,
              decoration: InputDecoration(
                hintText: 'Ask a question...',
                hintStyle: TextStyle(
                  color: context.textSecondary.withAlpha(150),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              style: TextStyle(color: context.textPrimary),
              onSubmitted: (_) => _submitQuestion(),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: context.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _submitQuestion,
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.help_outline_rounded,
            size: 64,
            color: context.textSecondary.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            'No questions yet',
            style: TextStyle(fontSize: 18, color: context.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Ask the first question!',
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary.withAlpha(160),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final question = _questions[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AnswerScreen(
                  questionId: question['id'],
                  questionText: question['text'] ?? '',
                ),
              ),
            ).then((_) => _loadQuestions());
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: this.context.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: this.context.borderColor),
              boxShadow: [
                BoxShadow(
                  color:
                      (this.context.isDark
                              ? Colors.black
                              : AsliColors.heritageBrown)
                          .withAlpha(6),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _parseColor(question['profile_color']),
                  child: Text(
                    (question['user_name'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question['text'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: this.context.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (question['user_name'] != null) ...[
                            Text(
                              question['user_name'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: this.context.accent,
                              ),
                            ),
                            Text(
                              ' · ',
                              style: TextStyle(
                                color: this.context.textSecondary,
                              ),
                            ),
                          ],
                          Text(
                            _timeAgo(question['created_at']),
                            style: TextStyle(
                              fontSize: 12,
                              color: this.context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: this.context.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _questionController.dispose();
    super.dispose();
  }
}
