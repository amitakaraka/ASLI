import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/theme_provider.dart';
import '../theme/theme_ext.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatelessWidget {
  final ThemeProvider themeProvider;
  const SettingsScreen({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Platform info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                context.isDark ? const Color(0xFF2A1A15) : AsliColors.heritageBrown,
                context.isDark ? AsliColors.darkMaroon : AsliColors.primaryMaroon,
              ]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.school_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Text("ASLI", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 8),
                Text("Campus Platform v20.0", style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14)),
                const SizedBox(height: 4),
                Text("Built for Andhra University · Est. 1926", style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _chipBadge("18 Modules"),
                    _chipBadge("80+ APIs"),
                    _chipBadge("JWT Auth"),
                    _chipBadge("WebSocket"),
                    _chipBadge("Dark Mode"),
                    _chipBadge("AU Data"),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ==================== DARK MODE TOGGLE ====================
          _sectionHeader(context, "Appearance"),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor),
            ),
            child: ListenableBuilder(
              listenable: themeProvider,
              builder: (context, _) {
                return Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.accent.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: context.accent,
                          size: 20,
                        ),
                      ),
                      title: Text("Dark Mode",
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: context.textPrimary)),
                      subtitle: Text(
                        themeProvider.isDarkMode ? "Night-friendly dark interface" : "Classic light interface",
                        style: TextStyle(fontSize: 12, color: context.textSecondary),
                      ),
                      trailing: Switch(
                        value: themeProvider.isDarkMode,
                        onChanged: (_) => themeProvider.toggleTheme(),
                        activeThumbColor: context.accent,
                      ),
                    ),
                    // Theme preview
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: themeProvider.isDarkMode ? AsliColors.darkBg : AsliColors.offWhite,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: themeProvider.isDarkMode ? AsliColors.darkBorder : AsliColors.lightAsh,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: themeProvider.isDarkMode ? AsliColors.darkMaroon : AsliColors.primaryMaroon,
                            child: const Text("R", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Preview",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: themeProvider.isDarkMode ? AsliColors.darkText : AsliColors.heritageBrown,
                                  )),
                              Text("How your app will look",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: themeProvider.isDarkMode ? AsliColors.darkSubtext : AsliColors.stoneBrown,
                                  )),
                            ],
                          ),
                          const Spacer(),
                          Icon(Icons.palette_rounded,
                              color: themeProvider.isDarkMode ? AsliColors.darkMaroon : AsliColors.primaryMaroon,
                              size: 20),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),



          _sectionHeader(context, "System Info"),
          _infoRow(context, "Version", "17.0.0"),
          _infoRow(context, "Backend", "Flask + SQLAlchemy + SocketIO"),
          _infoRow(context, "Frontend", "Flutter 3.x"),
          _infoRow(context, "Auth", "JWT (HS256)"),
          _infoRow(context, "Database", "SQLite (dev)"),
          _infoRow(context, "API Base", ApiService.baseUrl),
          _infoRow(context, "Modules", "auth, chat, qa, collx, events, notifs, analytics, messages, admin, bookmarks, polls, stories, leaderboard, studygroups, marketplace"),
          _infoRow(context, "Knowledge", "30+ AU categories (website + LinkedIn)"),
          _infoRow(context, "Theme", themeProvider.isDarkMode ? "Dark Mode" : "Light Mode"),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  static Widget _chipBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textSecondary, letterSpacing: 1)),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: context.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
