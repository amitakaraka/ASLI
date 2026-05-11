import 'dart:async';
import 'package:flutter/material.dart';
import '../services/connectivity_manager.dart';
import '../theme/colors.dart';

class ConnectionStatusBar extends StatefulWidget {
  final Widget child;
  final bool showInAppBar;
  final Color? onlineColor;
  final Color? offlineColor;
  final Color? reconnectingColor;

  const ConnectionStatusBar({
    super.key,
    required this.child,
    this.showInAppBar = true,
    this.onlineColor,
    this.offlineColor,
    this.reconnectingColor,
  });

  @override
  State<ConnectionStatusBar> createState() => _ConnectionStatusBarState();
}

class _ConnectionStatusBarState extends State<ConnectionStatusBar> {
  NetConnectionState _connectionState = NetConnectionState.disconnected;
  StreamSubscription? _stateSub;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _stateSub = ConnectivityManager.instance.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _connectionState = state;
          _showBanner = state != NetConnectionState.connected;
        });
      }
    });
    _connectionState = ConnectivityManager.instance.state;
    _showBanner = _connectionState != NetConnectionState.connected;
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  Color get _statusColor {
    switch (_connectionState) {
      case NetConnectionState.connected:
        return widget.onlineColor ?? AsliColors.statusSuccess;
      case NetConnectionState.connecting:
      case NetConnectionState.lost:
        return widget.reconnectingColor ?? AsliColors.statusWarning;
      case NetConnectionState.disconnected:
      case NetConnectionState.unavailable:
        return widget.offlineColor ?? AsliColors.statusError;
    }
  }

  IconData get _statusIcon {
    switch (_connectionState) {
      case NetConnectionState.connected:
        return Icons.wifi_rounded;
      case NetConnectionState.connecting:
      case NetConnectionState.lost:
        return Icons.sync_rounded;
      case NetConnectionState.disconnected:
      case NetConnectionState.unavailable:
        return Icons.wifi_off_rounded;
    }
  }

  String get _statusText {
    switch (_connectionState) {
      case NetConnectionState.connected:
        return 'Connected';
      case NetConnectionState.connecting:
        return 'Connecting...';
      case NetConnectionState.lost:
        return 'Connection lost - Reconnecting...';
      case NetConnectionState.disconnected:
      case NetConnectionState.unavailable:
        return 'No internet connection';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_showBanner)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _showBanner ? 36 : 0,
            color: _statusColor,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => ConnectivityManager.instance.reconnect(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(_statusIcon, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_connectionState == NetConnectionState.connected)
                        Icon(
                          Icons.check_circle,
                          color: Colors.white.withAlpha(200),
                          size: 14,
                        ),
                      if (_connectionState == NetConnectionState.connecting ||
                          _connectionState == NetConnectionState.lost)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withAlpha(200),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

class ConnectionIndicator extends StatelessWidget {
  final double size;
  final bool showLabel;
  final bool animated;

  const ConnectionIndicator({
    super.key,
    this.size = 10,
    this.showLabel = false,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = ConnectivityManager.instance.isConnected;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isConnected
                ? AsliColors.statusSuccess
                : AsliColors.statusError,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:
                    (isConnected
                            ? AsliColors.statusSuccess
                            : AsliColors.statusError)
                        .withAlpha(100),
                blurRadius: animated ? 6 : 0,
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              color: isConnected
                  ? AsliColors.statusSuccess
                  : AsliColors.statusError,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class ApiUrlIndicator extends StatelessWidget {
  const ApiUrlIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AsliColors.statusSuccess.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AsliColors.statusSuccess.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_done_rounded,
              size: 14,
              color: AsliColors.statusSuccess,
            ),
            const SizedBox(width: 4),
            Text(
              'Connected',
              style: TextStyle(
                fontSize: 10,
                color: AsliColors.statusSuccess,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Environment',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                'Development',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
