import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

class AnswerScreen extends StatefulWidget {
  final int questionId;
  final String questionText;

  const AnswerScreen({
    super.key,
    required this.questionId,
    required this.questionText,
  });

  @override
  State<AnswerScreen> createState() => _AnswerScreenState();
}

class _AnswerScreenState extends State<AnswerScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _answers = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAnswers();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _silentRefresh());
  }

  Future<void> _loadAnswers() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getAnswers(widget.questionId);
    if (mounted) {
      setState(() {
        _answers = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _silentRefresh() async {
    final data = await ApiService.getAnswers(widget.questionId);
    if (mounted && data.length != _answers.length) {
      setState(() => _answers = data);
    }
  }

  Future<void> _submitAnswer() async {
    if (_controller.text.trim().isEmpty) return;
    
    final success = await ApiService.addAnswer(widget.questionId, _controller.text.trim());
    if (success) {
      _controller.clear();
      _loadAnswers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Answer submitted!'),
            backgroundColor: context.accent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: const Text('Answers'),
      ),
      body: Column(
        children: [
          // Question Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: context.isDark ? AsliColors.darkSurface : AsliColors.lightAsh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question',
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.questionText,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Answer Count
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.question_answer_rounded, color: context.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${_answers.length} Answer${_answers.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Answers List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: context.accent))
                : _answers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 48, color: context.textSecondary),
                            const SizedBox(height: 8),
                            Text('No answers yet', style: TextStyle(color: context.textSecondary)),
                            const SizedBox(height: 4),
                            Text('Be the first to answer!', style: TextStyle(color: context.textSecondary, fontSize: 13)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAnswers,
                        color: context.accent,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _answers.length,
                          itemBuilder: (context, index) {
                            return _buildAnswerCard(_answers[index], index + 1);
                          },
                        ),
                      ),
          ),
          
          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceBg,
              border: Border(
                top: BorderSide(color: context.borderColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Write your answer...',
                      hintStyle: TextStyle(color: context.textSecondary),
                      filled: true,
                      fillColor: context.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: TextStyle(color: context.textPrimary),
                    maxLines: 2,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submitAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Submit'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AsliColors.primaryMaroon;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AsliColors.primaryMaroon;
    }
  }

  Widget _buildAnswerCard(Map<String, dynamic> answer, int index) {
    final hasUser = answer['user_name'] != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Answerer header
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: hasUser
                    ? _parseColor(answer['profile_color'])
                    : context.accent.withAlpha(25),
                child: Text(
                  hasUser ? answer['user_name'][0].toUpperCase() : '$index',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: hasUser ? 12 : 10,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasUser ? answer['user_name'] : 'Anonymous',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: context.textPrimary,
                  ),
                ),
              ),
              if (answer['created_at'] != null)
                Text(
                  _timeAgo(answer['created_at']),
                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Answer text
          Text(
            answer['text'] ?? '',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(dateStr));
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
}
