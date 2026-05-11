import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/env_config.dart';

/// Queued action for offline execution
class QueuedAction {
  final String id;
  final String endpoint;
  final String method;
  final Map<String, dynamic> data;
  final DateTime queuedAt;
  final int retryCount;

  QueuedAction({
    required this.id,
    required this.endpoint,
    required this.method,
    required this.data,
    required this.queuedAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'endpoint': endpoint,
    'method': method,
    'data': data,
    'queuedAt': queuedAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory QueuedAction.fromJson(Map<String, dynamic> json) => QueuedAction(
    id: json['id'],
    endpoint: json['endpoint'],
    method: json['method'],
    data: Map<String, dynamic>.from(json['data']),
    queuedAt: DateTime.parse(json['queuedAt']),
    retryCount: json['retryCount'] ?? 0,
  );

  QueuedAction copyWith({int? retryCount}) => QueuedAction(
    id: id,
    endpoint: endpoint,
    method: method,
    data: data,
    queuedAt: queuedAt,
    retryCount: retryCount ?? this.retryCount + 1,
  );
}

/// Offline queue service for queuing API calls when offline
/// Automatically syncs when connection is restored
class OfflineQueueService {
  static OfflineQueueService? _instance;
  static OfflineQueueService get instance =>
      _instance ??= OfflineQueueService._();

  OfflineQueueService._();

  static const String _queueBoxName = 'offline_queue';
  static const String _cacheBoxName = 'api_cache';

  Box<dynamic>? _queueBox;
  Box<dynamic>? _cacheBox;

  bool _initialized = false;
  bool _isSyncing = false;

  // Callbacks
  void Function(int pendingCount)? onQueueChange;
  void Function(QueuedAction action, bool success)? onActionSync;

  /// Initialize offline services
  Future<void> init() async {
    if (_initialized) return;

    // Open Hive boxes for queue and cache
    _queueBox = await Hive.openBox(_queueBoxName);
    _cacheBox = await Hive.openBox(_cacheBoxName);

    _initialized = true;
  }

  /// Check if offline mode is enabled
  bool get isEnabled => EnvConfig.enableOfflineMode;

  /// Get pending action count
  int get pendingCount {
    if (_queueBox == null) return 0;
    return _queueBox!.length;
  }

  /// Check if there are pending actions
  bool get hasPendingActions => pendingCount > 0;

  /// Queue an action for offline execution
  Future<void> queueAction({
    required String id,
    required String endpoint,
    required String method,
    required Map<String, dynamic> data,
  }) async {
    if (!isEnabled) return;
    if (_queueBox == null) await init();

    final action = QueuedAction(
      id: id,
      endpoint: endpoint,
      method: method,
      data: data,
      queuedAt: DateTime.now(),
    );

    await _queueBox!.put(id, jsonEncode(action.toJson()));
    onQueueChange?.call(pendingCount);
  }

  /// Remove an action from queue (after successful execution)
  Future<void> removeAction(String id) async {
    if (_queueBox == null) return;
    await _queueBox!.delete(id);
    onQueueChange?.call(pendingCount);
  }

  /// Get all pending actions
  List<QueuedAction> getPendingActions() {
    if (_queueBox == null) return [];

    final actions = <QueuedAction>[];
    for (final key in _queueBox!.keys) {
      final data = _queueBox!.get(key);
      if (data != null) {
        try {
          actions.add(QueuedAction.fromJson(jsonDecode(data)));
        } catch (e) {
          // Remove corrupted entry
          _queueBox!.delete(key);
        }
      }
    }

    // Sort by queue time
    actions.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return actions;
  }

  /// Execute all pending actions
  /// Returns number of successfully synced actions
  Future<int> syncPendingActions(
    Future<bool> Function(QueuedAction action) executor,
  ) async {
    if (_isSyncing) return 0;
    if (!hasPendingActions) return 0;

    _isSyncing = true;
    int synced = 0;

    final actions = getPendingActions();
    for (final action in actions) {
      // Skip if max retries exceeded
      if (action.retryCount >= 3) {
        await removeAction(action.id);
        continue;
      }

      try {
        final success = await executor(action);
        if (success) {
          await removeAction(action.id);
          synced++;
          onActionSync?.call(action, true);
        } else {
          // Re-queue with incremented retry
          final updatedAction = action.copyWith();
          await _queueBox!.put(action.id, jsonEncode(updatedAction.toJson()));
          onActionSync?.call(action, false);
        }
      } catch (e) {
        // Re-queue with incremented retry
        final updatedAction = action.copyWith();
        await _queueBox!.put(action.id, jsonEncode(updatedAction.toJson()));
        onActionSync?.call(action, false);
      }
    }

    _isSyncing = false;
    onQueueChange?.call(pendingCount);
    return synced;
  }

  /// Clear all pending actions
  Future<void> clearQueue() async {
    if (_queueBox == null) return;
    await _queueBox!.clear();
    onQueueChange?.call(0);
  }

  // ==================== CACHE MANAGEMENT ====================

  /// Cache API response
  Future<void> cacheResponse(
    String key,
    dynamic data, {
    Duration? expiry,
  }) async {
    if (_cacheBox == null) await init();

    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'expiry': expiry?.inMinutes != null
          ? DateTime.now().add(expiry!).toIso8601String()
          : null,
    };

    await _cacheBox!.put(key, jsonEncode(cacheData));
  }

  /// Get cached response
  Future<Map<String, dynamic>?> getCachedResponse(String key) async {
    if (_cacheBox == null) await init();

    final data = _cacheBox!.get(key);
    if (data == null) return null;

    try {
      final cacheData = jsonDecode(data);
      final expiry = cacheData['expiry'] != null
          ? DateTime.parse(cacheData['expiry'])
          : null;

      // Check if expired
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        await _cacheBox!.delete(key);
        return null;
      }

      return {
        'data': cacheData['data'],
        'timestamp': cacheData['timestamp'],
        'cached': true,
      };
    } catch (e) {
      return null;
    }
  }

  /// Check if cache exists and is valid
  Future<bool> hasValidCache(String key, {Duration? maxAge}) async {
    if (_cacheBox == null) await init();

    final data = _cacheBox!.get(key);
    if (data == null) return false;

    try {
      final cacheData = jsonDecode(data);
      final timestamp = DateTime.parse(cacheData['timestamp']);

      if (maxAge != null) {
        return DateTime.now().difference(timestamp) < maxAge;
      }

      // Check expiry if present
      final expiry = cacheData['expiry'];
      if (expiry != null) {
        return DateTime.now().isBefore(DateTime.parse(expiry));
      }

      // No expiry, check default cache duration
      return DateTime.now().difference(timestamp) < EnvConfig.cacheDuration;
    } catch (e) {
      return false;
    }
  }

  /// Clear cache
  Future<void> clearCache() async {
    if (_cacheBox == null) return;
    await _cacheBox!.clear();
  }

  /// Clear expired cache entries
  Future<void> clearExpiredCache() async {
    if (_cacheBox == null) return;

    final keys = _cacheBox!.keys.toList();
    for (final key in keys) {
      final data = _cacheBox!.get(key);
      if (data != null) {
        try {
          final cacheData = jsonDecode(data);
          final expiry = cacheData['expiry'];
          if (expiry != null &&
              DateTime.now().isAfter(DateTime.parse(expiry))) {
            await _cacheBox!.delete(key);
          }
        } catch (e) {
          // Remove corrupted entry
          await _cacheBox!.delete(key);
        }
      }
    }
  }

  /// Close services
  Future<void> dispose() async {
    await _queueBox?.close();
    await _cacheBox?.close();
  }
}
