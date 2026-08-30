import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:s_map/services/services.dart';

class MockLocalAuthentication extends LocalAuthentication {
  final List<BiometricType> mockBiometrics;
  final bool mockAuthenticateResult;

  MockLocalAuthentication({
    this.mockBiometrics = const [BiometricType.face],
    this.mockAuthenticateResult = true,
  });

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => mockBiometrics;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic>? authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async =>
      mockAuthenticateResult;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterLocalAuth Tests', () {
    test('init should complete and populate available biometrics', () async {
      final mockAuth = MockLocalAuthentication(
        mockBiometrics: [BiometricType.face, BiometricType.fingerprint],
      );
      final authService = FlutterLocalAuth(auth: mockAuth);

      expect(authService.initDone, isFalse);
      expect(authService.faceIdAvailable, isFalse);

      await authService.init();

      expect(authService.initDone, isTrue);
      expect(authService.faceIdAvailable, isTrue);

      // Calling init again should be idempotent without throwing
      await authService.init();
      expect(authService.initDone, isTrue);
    });

    test('authenticate should return true when mock returns true', () async {
      final mockAuth = MockLocalAuthentication(mockAuthenticateResult: true);
      final authService = FlutterLocalAuth(auth: mockAuth);

      final result = await authService.authenticate();
      expect(result, isTrue);
    });

    test('authenticate should return false when mock returns false', () async {
      final mockAuth = MockLocalAuthentication(mockAuthenticateResult: false);
      final authService = FlutterLocalAuth(auth: mockAuth);

      final result = await authService.authenticate();
      expect(result, isFalse);
    });
  });
}
