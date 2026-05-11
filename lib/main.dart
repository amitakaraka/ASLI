import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/chat_screen.dart';
import 'screens/map_screen.dart';
import 'screens/collx_feed_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/messaging_screen.dart';
import 'screens/profile_screen.dart';

import 'screens/login_screen.dart';
import 'api_service.dart';
import 'theme/colors.dart';
import 'theme/theme_provider.dart';
import 'theme/theme_ext.dart';
import 'providers/cache_provider.dart';
import 'services/socket_service.dart';
import 'services/secure_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize secure storage first (required before loadAuthState)
    await SecureStorageService.instance.init();
  } catch (e) {
    debugPrint('Storage init error (safe to ignore): $e');
  }
  
  try {
    // Load auth state from local storage (no network call)
    await ApiService.loadAuthState();
  } catch (e) {
    debugPrint('Auth state load error (safe to ignore): $e');
  }
  
  try {
    final cacheService = CacheService();
    await cacheService.init();
  } catch (e) {
    debugPrint('Cache init error (safe to ignore): $e');
  }
  
  // Start app IMMEDIATELY — never block on network
  runApp(ProviderScope(child: const AsliApp()));
  
  // Initialize connectivity in background (non-blocking, fire-and-forget)
  Future.delayed(const Duration(seconds: 2), () {
    ConnectionStatus.initialize();
  });
}

class AsliApp extends StatefulWidget {
  const AsliApp({super.key});

  @override
  State<AsliApp> createState() => _AsliAppState();
}

class _AsliAppState extends State<AsliApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeProvider,
      builder: (context, _) {
        return MaterialApp(
          title: 'Asli - Campus Platform',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: _themeProvider.themeMode,
          home: AuthGate(themeProvider: _themeProvider),
        );
      },
    );
  }
}

// Shows login or main app depending on auth state
class AuthGate extends StatefulWidget {
  final ThemeProvider themeProvider;
  const AuthGate({super.key, required this.themeProvider});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoggedIn = false;

  void _onLoginSuccess() {
    final userId = ApiService.currentUserId;
    if (userId > 0) {
      SocketService.instance.connect();
      SocketService.instance.authenticate(userId);
      SocketService.instance.subscribeToNotifications(userId);
    }
    setState(() => _isLoggedIn = true);
  }

  void _onLogout() {
    SocketService.instance.disconnect();
    ApiService.logout();
    setState(() => _isLoggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }
    return MainNavigation(
      onLogout: _onLogout,
      themeProvider: widget.themeProvider,
    );
  }
}

class MainNavigation extends StatefulWidget {
  final VoidCallback onLogout;
  final ThemeProvider themeProvider;
  const MainNavigation({
    super.key,
    required this.onLogout,
    required this.themeProvider,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  int _unreadNotifs = 0;
  int _unreadDMs = 0;
  bool _isConnected = true;
  Timer? _badgeTimer;

  @override
  void initState() {
    super.initState();
    _refreshBadges();
    _badgeTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshBadges(),
    );
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshBadges() async {
    final notifs = await ApiService.getUnreadCount();
    final dms = await ApiService.getUnreadDMCount();
    final connected = ApiService.isConnected;
    if (mounted) {
      setState(() {
        _unreadNotifs = notifs;
        _unreadDMs = dms;
        _isConnected = connected;
      });
    }
  }

  late final List<Widget> _screens = [
    const ChatScreen(),
    const MessagingScreen(),
    const CollxFeedScreen(),
    const MapScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeProvider,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: context.pageBg,
          body: Column(
            children: [
              // Connection health banner
              if (!_isConnected)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.redAccent,
                  child: const SafeArea(
                    bottom: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'No connection to server',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: IndexedStack(index: _currentIndex, children: _screens),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: context.surfaceBg,
              boxShadow: [
                BoxShadow(
                  color: (context.isDark ? Colors.black : AsliColors.heritageBrown)
                      .withAlpha(20),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
                _refreshBadges();
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.smart_toy_outlined),
                  selectedIcon: Icon(Icons.smart_toy_rounded),
                  label: 'Asli',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: _unreadDMs > 0,
                    label: Text('$_unreadDMs', style: const TextStyle(fontSize: 9)),
                    child: const Icon(Icons.mail_outline_rounded),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: _unreadDMs > 0,
                    label: Text('$_unreadDMs', style: const TextStyle(fontSize: 9)),
                    child: const Icon(Icons.mail_rounded),
                  ),
                  label: 'Chats',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.public_outlined),
                  selectedIcon: Icon(Icons.public_rounded),
                  label: 'CollX',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map_rounded),
                  label: 'Map',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: _unreadNotifs > 0,
                    label: Text(
                      '$_unreadNotifs',
                      style: const TextStyle(fontSize: 9),
                    ),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: _unreadNotifs > 0,
                    label: Text(
                      '$_unreadNotifs',
                      style: const TextStyle(fontSize: 9),
                    ),
                    child: const Icon(Icons.notifications_rounded),
                  ),
                  label: 'Alerts',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
