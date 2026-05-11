import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final Map<String, dynamic>? user;
  final String? token;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.token,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    Map<String, dynamic>? user,
    String? token,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      token: token ?? this.token,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && token != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<bool> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);

    final result = await ApiService.login(email, password);

    if (result['success'] == true) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: result['user'],
        token: result['token'],
      );
      return true;
    } else {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: result['error'] ?? 'Login failed',
      );
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String username,
    String department = '',
    String year = '',
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    final result = await ApiService.register(
      name: name,
      email: email,
      password: password,
      username: username,
      department: department,
      year: year,
    );

    if (result['success'] == true) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: result['user'],
        token: result['token'],
      );
      return true;
    } else {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: result['error'] ?? 'Registration failed',
      );
      return false;
    }
  }

  void logout() {
    ApiService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void updateUser(Map<String, dynamic> user) {
    state = state.copyWith(user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

final currentUserProvider = Provider<Map<String, dynamic>?>((ref) {
  return ref.watch(authProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});
