import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/services/local_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterLocalAuth Tests', () {
    test('init should complete and mark initDone as true', () async {
      final authService = FlutterLocalAuth();
      expect(authService.initDone, isFalse);

      await authService.init();
      expect(authService.initDone, isTrue);

      // Calling init again should be idempotent without throwing
      await authService.init();
      expect(authService.initDone, isTrue);
    });
  });
}
