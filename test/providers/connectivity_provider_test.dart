import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/providers/connectivity_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectivityState', () {
    test('initial state has correct defaults', () {
      const state = ConnectivityState();

      expect(state.status, ConnectivityStatus.unknown);
      expect(state.isOnline, isTrue);
    });

    test('offline state has correct values', () {
      const state = ConnectivityState(
        status: ConnectivityStatus.none,
        isOnline: false,
      );

      expect(state.status, ConnectivityStatus.none);
      expect(state.isOnline, isFalse);
    });

    test('wifi state has correct values', () {
      const state = ConnectivityState(
        status: ConnectivityStatus.wifi,
        isOnline: true,
      );

      expect(state.status, ConnectivityStatus.wifi);
      expect(state.isOnline, isTrue);
    });
  });
}
