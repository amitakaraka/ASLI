import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityStatus { wifi, cellular, ethernet, none, unknown }

class ConnectivityState {
  final ConnectivityStatus status;
  final bool isOnline;

  const ConnectivityState({
    this.status = ConnectivityStatus.unknown,
    this.isOnline = true,
  });

  ConnectivityState copyWith({ConnectivityStatus? status, bool? isOnline}) {
    return ConnectivityState(
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  final Connectivity _connectivity = Connectivity();

  ConnectivityNotifier() : super(const ConnectivityState()) {
    _init();
  }

  Future<void> _init() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);

    _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      state = const ConnectivityState(
        status: ConnectivityStatus.none,
        isOnline: false,
      );
      return;
    }

    ConnectivityStatus status;
    final result = results.first;

    switch (result) {
      case ConnectivityResult.wifi:
        status = ConnectivityStatus.wifi;
        break;
      case ConnectivityResult.mobile:
        status = ConnectivityStatus.cellular;
        break;
      case ConnectivityResult.ethernet:
        status = ConnectivityStatus.ethernet;
        break;
      default:
        status = ConnectivityStatus.unknown;
    }

    state = ConnectivityState(status: status, isOnline: true);
  }

  Future<bool> checkConnection() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
    return state.isOnline;
  }
}

final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
      return ConnectivityNotifier();
    });

final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).isOnline;
});
