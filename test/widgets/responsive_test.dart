import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/utils/responsive.dart';

void main() {
  group('Responsive', () {
    test('breakpoints defined correctly', () {
      expect(Responsive.mobileBreakpoint, 600);
      expect(Responsive.tabletBreakpoint, 1200);
    });
  });

  group('ResponsiveBuilder', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveBuilder(
            builder: (context, deviceType) {
              return const Text('Hello');
            },
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
    });
  });

  group('DeviceType enum', () {
    test('has all values', () {
      expect(DeviceType.values.length, 3);
    });
  });
}
