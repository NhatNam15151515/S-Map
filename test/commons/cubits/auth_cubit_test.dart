import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepos implements IAuthRepos {
  final User? mockGoogleUser;
  final bool shouldThrow;

  MockAuthRepos({this.mockGoogleUser, this.shouldThrow = false});

  @override
  Future<User?> login(String username, String password) async => null;

  @override
  Future<User?> signInWithGoogle() async {
    if (shouldThrow) {
      throw Exception('Network error during Google Sign In');
    }
    return mockGoogleUser;
  }

  @override
  Future<User?> getProfile() async => null;

  @override
  Future<User?> updateProfile(User user) async => user;

  @override
  Future<bool> logout() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (MethodCall methodCall) async {
        return <String, dynamic>{
          'appName': 'S-Map',
          'packageName': 'com.smap.app',
          'version': '1.0.0',
          'buildNumber': '1',
          'buildSignature': '',
        };
      },
    );
  });

  group('AuthCubit Tests - signInWithGoogle', () {
    test('signInWithGoogle success returns true and emits LoadingAuth then Authenticated', () async {
      final mockUser = User(
        id: '123',
        email: 'test@example.com',
        username: 'Test User',
      );
      final mockRepos = MockAuthRepos(mockGoogleUser: mockUser);
      final cubit = AuthCubit(authRepos: mockRepos);

      final result = await cubit.signInWithGoogle();

      expect(result, isTrue);
      expect(cubit.state.isAuthenticated, isTrue);
      expect(cubit.state.loggedInProfile?.email, 'test@example.com');
      await cubit.close();
    });

    test('signInWithGoogle returns false when user cancels (null)', () async {
      final mockRepos = MockAuthRepos(mockGoogleUser: null);
      final cubit = AuthCubit(authRepos: mockRepos);

      final result = await cubit.signInWithGoogle();

      expect(result, isFalse);
      expect(cubit.state.isUnAuthenticated, isTrue);
      await cubit.close();
    });

    test('signInWithGoogle returns false and handles exception gracefully', () async {
      final mockRepos = MockAuthRepos(shouldThrow: true);
      final cubit = AuthCubit(authRepos: mockRepos);

      final result = await cubit.signInWithGoogle();

      expect(result, isFalse);
      expect(cubit.state.isUnAuthenticated, isTrue);
      await cubit.close();
    });
  });
}

