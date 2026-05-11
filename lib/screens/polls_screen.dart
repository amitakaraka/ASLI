import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key});

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> with TickerProviderStateMixin {
  List<dynamic> _polls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPolls();
  }

  Future<void> _loadPolls() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getPolls();
    setState(() {
      if (data != null) _polls = data;
      _isLoading = false;
    });
  }

  Future<void> _votePoll(int pollId, int optionId) async {
    final result = await ApiService.votePoll(pollId, optionId);
    if (result != null && result['poll'] != null) {
      setState(() {
        final idx = _polls.indexWhere((p) => p['id'] == pollId);
        if (idx >= 0) _polls[idx] = result['poll'];
      });
    }
  }

  void _showCreatePollDialog() {
    final questionCtrl = TextEditingController();
    final optCtrls = [TextEditingController(), TextEditingController()];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20, right: 20, top: 20,
              ),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: context.borderColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text("Create Poll", style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary,
                    )),
                    const SizedBox(height: 16),
                    TextField(
                      controller: questionCtrl,
                      maxLength: 280,
                      decoration: InputDecoration(
                        hintText: "Ask a question...",
                        hintStyle: TextStyle(color: context.textSecondary),
                        filled: true,
                        fillColor: context.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(color: context.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(optCtrls.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: context.accent.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text("${i + 1}", style: TextStyle(
                                  color: context.accent, fontWeight: FontWeight.bold, fontSize: 13,
                                )),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: optCtrls[i],
                                decoration: InputDecoration(
                                  hintText: "Option ${i + 1}",
                                  hintStyle: TextStyle(color: context.textSecondary, fontSize: 14),
                                  filled: true,
                                  fillColor: context.inputFill,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                style: TextStyle(color: context.textPrimary, fontSize: 14),
                              ),
                            ),
                            if (i >= 2) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  setDialogState(() => optCtrls.removeAt(i));
                                },
                                child: Icon(Icons.close_rounded, color: Colors.red.shade300, size: 20),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    if (optCtrls.length < 4)
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(() => optCtrls.add(TextEditingController()));
                        },
                        icon: Icon(Icons.add_rounded, size: 18, color: context.accent),
                        label: Text("Add Option", style: TextStyle(color: context.accent)),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final q = questionCtrl.text.trim();
                          final opts = optCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                          if (q.isEmpty || opts.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Need a question and at least 2 options")),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          final res = await ApiService.createPoll(q, opts);
                          if (res != null) {
                            _loadPolls();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Poll created! 🗳️")),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Create Poll", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: const Text("Polls", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadPolls,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: context.accent,
        foregroundColor: Colors.white,
        onPressed: _showCreatePollDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text("New Poll", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.accent))
          : _polls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.poll_rounded, size: 64, color: context.textSecondary.withAlpha(100)),
                      const SizedBox(height: 12),
                      Text("No polls yet!", style: TextStyle(fontSize: 18, color: context.textSecondary)),
                      const SizedBox(height: 6),
                      Text("Create the first poll!", style: TextStyle(fontSize: 14, color: context.textSecondary.withAlpha(160))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPolls,
                  color: context.accent,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _polls.length,
                    itemBuilder: (context, index) => _buildPollCard(_polls[index]),
                  ),
                ),
    );
  }

  Widget _buildPollCard(Map<String, dynamic> poll) {
    final options = poll['options'] as List<dynamic>? ?? [];
    final totalVotes = poll['total_votes'] ?? 0;
    final userVote = poll['user_vote'];
    final hasVoted = userVote != null;
    final creatorColor = _parseColor(poll['creator_color']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: (context.isDark ? Colors.black : AsliColors.heritageBrown).withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Creator info
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: creatorColor,
                child: Text(
                  (poll['creator_name'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(poll['creator_name'] ?? 'Unknown',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.textPrimary)),
                    Text("@${poll['creator_username'] ?? 'user'}",
                        style: TextStyle(fontSize: 12, color: context.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.accent.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.poll_rounded, size: 14, color: context.accent),
                    const SizedBox(width: 4),
                    Text("Poll", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.accent)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Question
          Text(
            poll['question'] ?? '',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 14),

          // Options
          ...List.generate(options.length, (i) {
            final opt = options[i];
            final isSelected = userVote == opt['id'];
            final pct = (opt['percentage'] ?? 0).toDouble();

            return GestureDetector(
              onTap: () => _votePoll(poll['id'], opt['id']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? context.accent : context.borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    children: [
                      // Animated progress bar
                      if (hasVoted)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          height: 48,
                          width: MediaQuery.of(context).size.width * (pct / 100) * 0.7,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.accent.withAlpha(context.isDark ? 50 : 30)
                                : (context.isDark ? Colors.white.withAlpha(8) : AsliColors.lightAsh.withAlpha(60)),
                          ),
                        ),
                      // Content
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(Icons.check_circle_rounded, size: 18, color: context.accent),
                              ),
                            Expanded(
                              child: Text(
                                opt['text'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? context.accent : context.textPrimary,
                                ),
                              ),
                            ),
                            if (hasVoted) ...[
                              Text(
                                "${pct.toStringAsFixed(1)}%",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? context.accent : context.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "(${opt['votes']})",
                                style: TextStyle(fontSize: 11, color: context.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 8),
          // Total votes
          Row(
            children: [
              Icon(Icons.people_outline_rounded, size: 16, color: context.textSecondary),
              const SizedBox(width: 6),
              Text(
                "$totalVotes vote${totalVotes != 1 ? 's' : ''}",
                style: TextStyle(fontSize: 13, color: context.textSecondary, fontWeight: FontWeight.w500),
              ),
              if (hasVoted) ...[
                const SizedBox(width: 10),
                Icon(Icons.check_rounded, size: 14, color: Colors.green),
                const SizedBox(width: 3),
                Text("Voted", style: TextStyle(fontSize: 12, color: Colors.green.shade400, fontWeight: FontWeight.w600)),
              ],
            ],
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
}
