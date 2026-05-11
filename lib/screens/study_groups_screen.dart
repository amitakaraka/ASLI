import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

class StudyGroupsScreen extends StatefulWidget {
  const StudyGroupsScreen({super.key});

  @override
  State<StudyGroupsScreen> createState() => _StudyGroupsScreenState();
}

class _StudyGroupsScreenState extends State<StudyGroupsScreen> {
  List<dynamic> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final data = await ApiService.getStudyGroups();
    if (mounted) {
      setState(() {
        _groups = data ?? [];
        _isLoading = false;
      });
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AsliColors.primaryMaroon;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AsliColors.primaryMaroon;
    }
  }

  void _showCreateGroup() {
    final nameCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedColor = '#3B82F6';
    String selectedEmoji = '📚';
    final colors = ['#3B82F6', '#8B5CF6', '#10B981', '#F59E0B', '#EF4444', '#EC4899', '#06B6D4', '#6366F1'];
    final emojis = ['📚', '💻', '🧠', '🔬', '📐', '🎨', '🌐', '🏗️', '📊', ''];

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
                        decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text("Create Study Group", style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary,
                    )),
                    const SizedBox(height: 4),
                    Text("Collaborate with classmates 🤝", style: TextStyle(
                      fontSize: 13, color: context.textSecondary,
                    )),
                    const SizedBox(height: 16),

                    _dialogTextField(nameCtrl, "Group Name", "e.g. DSA Warriors"),
                    const SizedBox(height: 10),
                    _dialogTextField(subjectCtrl, "Subject", "e.g. Data Structures"),
                    const SizedBox(height: 10),
                    _dialogTextField(descCtrl, "Description (optional)", "What's this group about?", maxLines: 2),
                    const SizedBox(height: 14),

                    // Emoji picker
                    Text("Icon", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8, runSpacing: 6,
                      children: emojis.map((e) {
                        final isSel = e == selectedEmoji;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedEmoji = e),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: isSel ? _parseColor(selectedColor).withAlpha(30) : context.inputFill,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSel ? _parseColor(selectedColor) : Colors.transparent, width: 2,
                              ),
                            ),
                            child: Center(child: Text(e, style: const TextStyle(fontSize: 18))),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Color picker
                    Text("Color", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8, runSpacing: 6,
                      children: colors.map((c) {
                        final isSel = c == selectedColor;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = c),
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _parseColor(c),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSel ? Colors.white : Colors.transparent, width: 3),
                              boxShadow: isSel ? [BoxShadow(color: _parseColor(c).withAlpha(100), blurRadius: 8)] : null,
                            ),
                            child: isSel ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty || subjectCtrl.text.trim().isEmpty) return;
                          Navigator.pop(ctx);
                          await ApiService.createStudyGroup(
                            nameCtrl.text.trim(),
                            subjectCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            emoji: selectedEmoji,
                            color: selectedColor,
                          );
                          _loadGroups();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Study group created! 📚")),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _parseColor(selectedColor),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Create Group", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _dialogTextField(TextEditingController ctrl, String label, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.textSecondary, fontSize: 13),
        hintText: hint,
        hintStyle: TextStyle(color: context.textSecondary.withAlpha(120)),
        filled: true,
        fillColor: context.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      style: TextStyle(color: context.textPrimary),
    );
  }

  void _showGroupDetail(Map<String, dynamic> group) async {
    final detail = await ApiService.getStudyGroupDetail(group['id']);
    if (!mounted || detail == null) return;

    final members = detail['members'] as List<dynamic>? ?? [];
    final groupColor = _parseColor(detail['color']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                // Group icon
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: groupColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(child: Text(detail['emoji'] ?? '📚', style: const TextStyle(fontSize: 28))),
                ),
                const SizedBox(height: 10),
                Text(detail['name'] ?? '', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary,
                )),
                Text(detail['subject'] ?? '', style: TextStyle(
                  fontSize: 14, color: groupColor, fontWeight: FontWeight.w600,
                )),
                if ((detail['description'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(detail['description'], style: TextStyle(
                    fontSize: 13, color: context.textSecondary,
                  ), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 6),
                Text("${detail['member_count']}/${detail['max_members']} members", style: TextStyle(
                  fontSize: 12, color: context.textSecondary,
                )),
                const SizedBox(height: 16),

                // Members list
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Members", style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary,
                  )),
                ),
                const SizedBox(height: 8),
                ...members.map((m) {
                  final mColor = _parseColor(m['profile_color']);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: mColor,
                          child: Text(
                            (m['name'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['name'] ?? 'Unknown', style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary,
                              )),
                              Text("@${m['username']} • ${m['department'] ?? ''}", style: TextStyle(
                                fontSize: 11, color: context.textSecondary,
                              )),
                            ],
                          ),
                        ),
                        if (m['role'] == 'admin')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: groupColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text("Admin", style: TextStyle(
                              fontSize: 11, color: groupColor, fontWeight: FontWeight.w600,
                            )),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // Join/Leave button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      if (detail['is_member'] == true) {
                        await ApiService.leaveStudyGroup(detail['id']);
                      } else {
                        await ApiService.joinStudyGroup(detail['id']);
                      }
                      _loadGroups();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: detail['is_member'] == true ? Colors.red.shade400 : groupColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      detail['is_member'] == true ? "Leave Group" : "Join Group",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: const Text("Study Groups", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: context.isDark ? AsliColors.darkSurface : AsliColors.heritageBrown,
        foregroundColor: context.isDark ? AsliColors.darkText : Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.accent))
          : _groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("📚", style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text("No study groups yet", style: TextStyle(
                        fontSize: 16, color: context.textSecondary,
                      )),
                      const SizedBox(height: 6),
                      Text("Create one to get started!", style: TextStyle(
                        fontSize: 13, color: context.textSecondary,
                      )),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadGroups,
                  color: context.accent,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _groups.length,
                    itemBuilder: (_, i) => _buildGroupCard(_groups[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGroup,
        backgroundColor: context.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("New Group", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildGroupCard(dynamic group) {
    final color = _parseColor(group['color']);
    final isMember = group['is_member'] == true;

    return GestureDetector(
      onTap: () => _showGroupDetail(Map<String, dynamic>.from(group)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isMember ? color.withAlpha(100) : context.borderColor),
          boxShadow: [
            BoxShadow(color: color.withAlpha(8), blurRadius: 12, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            // Group icon
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(group['emoji'] ?? '📚', style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 14),
            // Group info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          group['name'] ?? 'Untitled',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMember) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text("Joined", style: TextStyle(
                            fontSize: 10, color: color, fontWeight: FontWeight.w700,
                          )),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(group['subject'] ?? '', style: TextStyle(
                    fontSize: 13, color: color, fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.group_rounded, size: 14, color: context.textSecondary),
                      const SizedBox(width: 4),
                      Text("${group['member_count']}/${group['max_members']}", style: TextStyle(
                        fontSize: 12, color: context.textSecondary,
                      )),
                      Text(" • by ${group['creator_name']}", style: TextStyle(
                        fontSize: 12, color: context.textSecondary,
                      )),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.textSecondary),
          ],
        ),
      ),
    );
  }
}
