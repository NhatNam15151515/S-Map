import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/fallbacks/fallbacks.dart';
import 'package:s_map/services/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirebaseAuthService Tests', () {
    test('FirebaseAuthService singleton instance is not null', () {
      final instance = FirebaseAuthService.instance;
      expect(instance, isNotNull);
    });

    test('signInAnonymously returns a valid fallback User when Firebase is uninitialized', () async {
      final service = FirebaseAuthService.instance;
      final user = await service.signInAnonymously();

      expect(user, isNotNull);
      expect(user?.id, isNotEmpty);
      expect(user?.username, startsWith('Khách_'));
    });

    test('NoOpFirebaseAuthService behaves safely in decoupled environments', () async {
      const noOp = NoOpFirebaseAuthService();

      expect(noOp.currentUser, isNull);
      expect(await noOp.signInWithGoogle(), isNull);
      expect(await noOp.signInAnonymously(), isNull);
      await noOp.signOut(); // No exception
    });
  });
}
