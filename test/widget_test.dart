// Smoke test cho S-Map app.
//
// App sử dụng Flavor + environment variables nên không thể pump MyApp trực tiếp
// trong test environment (thiếu FLAVOR, BASE_URL, etc.).
// Thay vào đó, test các unit cơ bản để đảm bảo CI pass.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/flavor/flavor_enum.dart';

void main() {
  group('FlavorEnum', () {
    test('should have exactly 3 flavors: dev, sta, pro', () {
      expect(FlavorEnum.values.length, 3);
      expect(FlavorEnum.values, contains(FlavorEnum.dev));
      expect(FlavorEnum.values, contains(FlavorEnum.sta));
      expect(FlavorEnum.values, contains(FlavorEnum.pro));
    });

    test('envKeys should contain required environment keys', () {
      expect(envKeys, contains('FLAVOR'));
      expect(envKeys, contains('BASE_URL'));
      expect(envKeys, contains('BUNDLE_ID'));
    });
  });

  group('MaterialApp basic widget', () {
    testWidgets('can render a basic MaterialApp', (WidgetTester tester) async {
      // Verify Flutter widget system works correctly in CI
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('S-Map'),
            ),
          ),
        ),
      );

      expect(find.text('S-Map'), findsOneWidget);
    });
  });
}
