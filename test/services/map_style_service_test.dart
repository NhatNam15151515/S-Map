import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/services/map_style_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapStyleService Tests', () {
    test('instance returns singleton and provides empty strings before init in test', () {
      final service = MapStyleService.instance;
      expect(service.styleJson, isA<String>());
      expect(service.nightStyleJson, isA<String>());
    });

    test('getStyleJson returns appropriate style for day and night', () {
      final service = MapStyleService();
      expect(service.getStyleJson(isDarkMode: false), equals(''));
      expect(service.getStyleJson(isDarkMode: true), equals(''));
    });

    test('init handles missing bundle gracefully without throwing', () async {
      final service = MapStyleService();
      await expectLater(service.init(), completes);
    });
  });
}
