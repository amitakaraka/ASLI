import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});
  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  List<dynamic> _listings = [];
  List<String> _categories = [];
  String _selectedCategory = '';
  bool _isLoading = true;

  static const _catIcons = {
    'textbooks': '📚', 'notes': '📝', 'electronics': '💻',
    'clothing': '👕', 'sports': '🏸', 'other': '📦',
  };
  static const _catColors = {
    'textbooks': AsliColors.primaryMaroon, 'notes': AsliColors.accentIndigo,
    'electronics': AsliColors.accentSlate, 'clothing': AsliColors.accentPlum,
    'sports': AsliColors.accentSage, 'other': AsliColors.warmSand,
  };
  static const _condLabels = {
    'new': '🏷️ New', 'like_new': '✨ Like New',
    'good': '👍 Good', 'fair': '🤝 Fair', 'poor': '⚠️ Poor',
  };

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getListings(
      category: _selectedCategory.isNotEmpty ? _selectedCategory : null,
    );
    if (mounted && data != null) {
      setState(() {
        _listings = data['listings'] ?? [];
        _categories = List<String>.from(data['categories'] ?? []);
        _isLoading = false;
      });
    } else if (mounted) setState(() => _isLoading = false);
  }

  void _showCreateListing() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String selCat = 'textbooks';
    String selCond = 'good';

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          final catColor = _catColors[selCat] ?? AsliColors.primaryMaroon;
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20, right: 20, top: 20,
            ),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 14),
                Row(children: [
                  const Text("🛒 ", style: TextStyle(fontSize: 22)),
                  Text("Sell Something", style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary,
                  )),
                ]),
                const SizedBox(height: 14),
                // Title
                TextField(
                  controller: titleCtrl, maxLength: 120,
                  decoration: InputDecoration(
                    hintText: "What are you selling?",
                    hintStyle: TextStyle(color: context.textSecondary.withAlpha(120)),
                    filled: true, fillColor: context.inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    counterStyle: TextStyle(color: context.textSecondary, fontSize: 11),
                  ),
                  style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                // Description
                TextField(
                  controller: descCtrl, maxLines: 3, maxLength: 500,
                  decoration: InputDecoration(
                    hintText: "Describe condition, reason for selling...",
                    hintStyle: TextStyle(color: context.textSecondary.withAlpha(120)),
                    filled: true, fillColor: context.inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    counterStyle: TextStyle(color: context.textSecondary, fontSize: 11),
                  ),
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                ),
                const SizedBox(height: 6),
                // Price
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixText: "₹ ", hintText: "Price",
                    hintStyle: TextStyle(color: context.textSecondary.withAlpha(120)),
                    filled: true, fillColor: context.inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                // Category chips
                Text("Category", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: _catIcons.entries.map((e) {
                  final isSel = e.key == selCat;
                  final color = _catColors[e.key]!;
                  return GestureDetector(
                    onTap: () => setS(() => selCat = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? color.withAlpha(25) : context.inputFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSel ? color : Colors.transparent, width: 1.5),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(e.value, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(e.key[0].toUpperCase() + e.key.substring(1), style: TextStyle(
                          fontSize: 12, color: isSel ? color : context.textSecondary,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                        )),
                      ]),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 12),
                // Condition
                Text("Condition", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: _condLabels.entries.map((e) {
                  final isSel = e.key == selCond;
                  return GestureDetector(
                    onTap: () => setS(() => selCond = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? catColor.withAlpha(25) : context.inputFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSel ? catColor : Colors.transparent, width: 1.5),
                      ),
                      child: Text(e.value, style: TextStyle(
                        fontSize: 12, color: isSel ? catColor : context.textSecondary,
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                      )),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await ApiService.createListing({
                      'title': titleCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'price': double.tryParse(priceCtrl.text.trim()) ?? 0,
                      'category': selCat,
                      'condition': selCond,
                    });
                    _load();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Listing posted! 🛒")),
                      );
                    }
                  },
                  icon: const Icon(Icons.sell_rounded),
                  label: const Text("Post Listing", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: catColor, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )),
              ],
            )),
          );
        });
      },
    );
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso));
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: const Text("🛒 Marketplace", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: context.isDark ? AsliColors.darkSurface : AsliColors.heritageBrown,
        foregroundColor: context.isDark ? AsliColors.darkText : Colors.white, elevation: 0,
      ),
      body: Column(children: [
        // Category filter
        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
          color: context.cardBg,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _chip('All', '', context.accent),
              ..._categories.map((c) => _chip(
                '${_catIcons[c] ?? '📦'} ${c[0].toUpperCase()}${c.substring(1)}',
                c, _catColors[c] ?? context.accent,
              )),
            ]),
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: context.accent))
              : _listings.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text("🛍️", style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 10),
                      Text("No listings yet", style: TextStyle(fontSize: 16, color: context.textSecondary)),
                      Text("Be the first to sell!", style: TextStyle(fontSize: 13, color: context.textSecondary)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _load, color: context.accent,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80, top: 6),
                        itemCount: _listings.length,
                        itemBuilder: (_, i) => _card(_listings[i]),
                      ),
                    ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateListing,
        backgroundColor: context.accent,
        icon: const Icon(Icons.sell_rounded, color: Colors.white),
        label: const Text("Sell", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    final sel = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () { setState(() => _selectedCategory = value); _load(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? color : context.inputFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? color : context.borderColor),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 13, color: sel ? Colors.white : context.textSecondary,
            fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
          )),
        ),
      ),
    );
  }

  Widget _card(dynamic item) {
    final cat = item['category'] ?? 'other';
    final catColor = _catColors[cat] ?? AsliColors.primaryMaroon;
    final catIcon = _catIcons[cat] ?? '📦';
    final cond = item['condition'] ?? 'good';
    final seller = item['seller'] ?? {};
    final isSold = item['is_sold'] == true;
    final isInterested = item['is_interested'] == true;
    final interestCount = item['interest_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: context.cardBg, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isSold ? Colors.grey.withAlpha(60) : context.borderColor),
        boxShadow: [BoxShadow(color: catColor.withAlpha(8), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Opacity(
        opacity: isSold ? 0.6 : 1.0,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header with seller info
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Color(int.parse((seller['profile_color'] ?? '#A9523C').replaceFirst('#', '0xFF'))),
                child: Text(
                  (seller['name'] ?? 'U')[0],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(seller['name'] ?? 'Unknown', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary,
                )),
                Text("${seller['department'] ?? ''} • ${_timeAgo(item['created_at'])}", style: TextStyle(
                  fontSize: 11, color: context.textSecondary,
                )),
              ])),
              // Price tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [catColor, catColor.withAlpha(180)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text("₹${item['price']?.toStringAsFixed(0) ?? '0'}", style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16,
                )),
              ),
            ]),
          ),

          // Title + description
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(item['title'] ?? '', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary,
              decoration: isSold ? TextDecoration.lineThrough : null,
            )),
          ),
          if ((item['description'] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(item['description'], style: TextStyle(
                fontSize: 13, color: context.textSecondary, height: 1.4,
              ), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),

          // Category + Condition tags
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: catColor.withAlpha(15), borderRadius: BorderRadius.circular(8)),
                child: Text("$catIcon ${cat[0].toUpperCase()}${cat.substring(1)}", style: TextStyle(
                  fontSize: 11, color: catColor, fontWeight: FontWeight.w600,
                )),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: context.inputFill, borderRadius: BorderRadius.circular(8)),
                child: Text(_condLabels[cond] ?? cond, style: TextStyle(
                  fontSize: 11, color: context.textSecondary,
                )),
              ),
              if (isSold) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                  child: const Text("SOLD", style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ],
            ]),
          ),

          // Interest bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: context.inputFill.withAlpha(80),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: isSold ? null : () async {
                  await ApiService.toggleInterest(item['id']);
                  _load();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isInterested ? catColor.withAlpha(20) : context.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isInterested ? catColor : context.borderColor),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      isInterested ? Icons.favorite : Icons.favorite_border,
                      size: 16, color: isInterested ? catColor : context.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text("$interestCount interested", style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: isInterested ? catColor : context.textSecondary,
                    )),
                  ]),
                ),
              ),
              const Spacer(),
              if (!isSold)
                Text("Tap ❤️ to show interest", style: TextStyle(
                  fontSize: 11, color: context.textSecondary.withAlpha(100),
                )),
            ]),
          ),
        ]),
      ),
    );
  }
}
