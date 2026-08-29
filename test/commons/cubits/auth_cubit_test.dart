import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/enums/enums.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepos implements IAuthRepos {
  final User? mockGoogleUser;
  final User? mockAnonUser;
  final bool shouldThrow;

  MockAuthRepos({
    this.mockGoogleUser,
    this.mockAnonUser,
    this.shouldThrow = false,
  });

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
  Future<User?> signInAnonymously() async {
    if (shouldThrow) {
      throw Exception('Firebase auth anonymous error');
    }
    return mockAnonUser ?? User(id: 'anon_123', username: 'Khách_123');
  }

  @override
  Future<User?> getProfile() async => null;

  @override
  Future<User?> updateProfile(User user) async => user;

  @override
  Future<bool> logout() async => true;
}

class FailingSharedPreferences extends NoOpSharedPreferences {
  @override
  Future<bool> getOnboardingCompleted() async {
    throw Exception('Native storage read failure');
  }
}

class SaveFailingSharedPreferences extends NoOpSharedPreferences {
  @override
  Future<void> saveOnboardingCompleted(bool value) async {
    throw Exception('Native storage write failure');
  }
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

  group('AuthCubit Tests - signInAnonymously', () {
    test('signInAnonymously success sets authenticated state with anonymous user', () async {
      final mockRepos = MockAuthRepos(
        mockAnonUser: User(id: 'anon_test_99', username: 'Khách_test_99'),
      );
      final cubit = AuthCubit(authRepos: mockRepos);

      final result = await cubit.signInAnonymously();

      expect(result, isTrue);
      expect(cubit.state.isAuthenticated, isTrue);
      expect(cubit.state.loggedInProfile?.id, 'anon_test_99');
      expect(cubit.state.loggedInProfile?.username, 'Khách_test_99');
      await cubit.close();
    });

    test('signInAnonymously handles exception gracefully and emits unAuthenticated', () async {
      final mockRepos = MockAuthRepos(shouldThrow: true);
      final cubit = AuthCubit(authRepos: mockRepos);

      final result = await cubit.signInAnonymously();

      expect(result, isFalse);
      expect(cubit.state.isUnAuthenticated, isTrue);
      expect(cubit.state.errorMessage, contains('Firebase auth anonymous error'));
      await cubit.close();
    });
  });

  group('AuthCubit Tests - Onboarding Flow', () {
    test('onAppStarted emits onboarding on fresh install', () async {
      final mockPrefs = NoOpSharedPreferences();
      final cubit = AuthCubit(sharedPreferences: mockPrefs);

      await cubit.onAppStarted();

      expect(cubit.state.isOnboarding, isTrue);
      expect(cubit.state.type, AuthStateType.onboarding);
      await cubit.close();
    });

    test('onAppStarted falls back to onboarding when getOnboardingCompleted throws', () async {
      final mockPrefs = FailingSharedPreferences();
      final cubit = AuthCubit(sharedPreferences: mockPrefs);

      await cubit.onAppStarted();

      expect(cubit.state.isOnboarding, isTrue);
      expect(cubit.state.type, AuthStateType.onboarding);
      await cubit.close();
    });

    test('completeOnboarding saves flag and transitions to authenticated guest', () async {
      final mockPrefs = NoOpSharedPreferences();
      final cubit = AuthCubit(sharedPreferences: mockPrefs);

      await cubit.completeOnboarding();

      expect(cubit.state.isAuthenticated, isTrue);
      expect(await mockPrefs.getOnboardingCompleted(), isTrue);
      await cubit.close();
    });

    test('completeOnboarding transitions to authenticated guest even when saveOnboardingCompleted throws', () async {
      final mockPrefs = SaveFailingSharedPreferences();
      final cubit = AuthCubit(sharedPreferences: mockPrefs);

      await cubit.completeOnboarding();

      expect(cubit.state.isAuthenticated, isTrue);
      await cubit.close();
    });
  });
}

