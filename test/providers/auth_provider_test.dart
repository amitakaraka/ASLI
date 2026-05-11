import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/providers/auth_provider.dart';

void main() {
  group('AuthState', () {
    test('initial state has correct defaults', () {
      const state = AuthState();

      expect(state.status, AuthStatus.initial);
      expect(state.user, isNull);
      expect(state.token, isNull);
      expect(state.errorMessage, isNull);
      expect(state.isAuthenticated, isFalse);
    });

    test('authenticated state returns isAuthenticated true', () {
      final state = AuthState(
        status: AuthStatus.authenticated,
        user: {'id': 1, 'name': 'Test'},
        token: 'test_token',
      );

      expect(state.isAuthenticated, isTrue);
    });

    test('copyWith creates new instance with updated values', () {
      const original = AuthState(status: AuthStatus.initial);
      final updated = original.copyWith(
        status: AuthStatus.authenticated,
        token: 'new_token',
      );

      expect(updated.status, AuthStatus.authenticated);
      expect(updated.token, 'new_token');
      expect(original.status, AuthStatus.initial);
    });
  });

  group('AuthNotifier', () {
    late ProviderContainer container;
    late AuthNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(authProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('logout clears state', () {
      notifier.logout();

      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
      expect(container.read(authProvider).token, isNull);
    });

    test('updateUser updates the current user without network access', () {
      notifier.updateUser({'id': 1, 'name': 'Updated'});

      expect(container.read(authProvider).user?['name'], 'Updated');
    });
  });
}
