import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _deptController;
  late TextEditingController _yearController;
  String _selectedColor = '#4F46E5';
  bool _isSaving = false;

  final _colorOptions = [
    '#A9523C', '#E11D48', '#059669', '#D97706', '#7C3AED',
    '#4F46E5', '#0EA5E9', '#DC2626', '#16A34A', '#9333EA',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['name'] ?? '');
    _bioController = TextEditingController(text: widget.user['bio'] ?? '');
    _deptController = TextEditingController(text: widget.user['department'] ?? '');
    _yearController = TextEditingController(text: widget.user['year'] ?? '');
    _selectedColor = widget.user['profile_color'] ?? '#A9523C';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _deptController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AsliColors.primaryMaroon;
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    final result = await ApiService.updateProfile(
      name: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      department: _deptController.text.trim(),
      year: _yearController.text.trim(),
      profileColor: _selectedColor,
    );
    setState(() => _isSaving = false);

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated!'),
          backgroundColor: context.accent,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar preview
            Center(
              child: Column(
                children: [
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_parseColor(_selectedColor), _parseColor(_selectedColor).withAlpha(180)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: _parseColor(_selectedColor).withAlpha(60), blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text("@${widget.user['username']}", style: TextStyle(color: context.textSecondary, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Color picker section
            Text("Profile Color", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.textPrimary)),
            const SizedBox(height: 4),
            Text("Choose your avatar accent", style: TextStyle(fontSize: 12, color: context.textSecondary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderColor),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _colorOptions.map((color) => GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _parseColor(color),
                      shape: BoxShape.circle,
                      border: _selectedColor == color
                          ? Border.all(color: context.textPrimary, width: 3)
                          : Border.all(color: Colors.transparent, width: 3),
                      boxShadow: _selectedColor == color
                          ? [BoxShadow(color: _parseColor(color).withAlpha(100), blurRadius: 10, spreadRadius: 1)]
                          : null,
                    ),
                    child: _selectedColor == color
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                        : null,
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 28),

            // Form fields
            _buildField("Full Name", _nameController, Icons.person_rounded),
            _buildField("Bio", _bioController, Icons.description_rounded, maxLines: 3, maxLength: 160),
            _buildField("Department", _deptController, Icons.school_rounded),
            _buildField("Year", _yearController, Icons.calendar_today_rounded),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveProfile,
                icon: const Icon(Icons.save_rounded),
                label: const Text("Save Changes", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1, int? maxLength}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: context.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            onChanged: label == "Full Name" ? (_) => setState(() {}) : null,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: context.accent, size: 20),
              filled: true,
              fillColor: context.cardBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.accent, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
