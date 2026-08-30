import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/services.dart';

// Backward compatibility alias
typedef AuthRepos = IAuthRepos;

class AuthReposImpl implements IAuthRepos {
  final IFirebaseAuthService _authService;
  final IFireStoreService _fireStore;

  AuthReposImpl({
    IFirebaseAuthService? authService,
    IFireStoreService? fireStore,
  })  : _authService = authService ?? FirebaseAuthService.instance,
        _fireStore = fireStore ?? FireStoreService();

  @override
  Future<User?> login(String username, String password) async {
    return User(
      username: username.trim(),
    );
  }

  @override
  Future<User?> signInWithGoogle() async {
    return await _authService.signInWithGoogle();
  }

  @override
  Future<User?> signInAnonymously() async {
    return await _authService.signInAnonymously();
  }

  @override
  Future<User?> getProfile() async {
    final fbUser = _authService.currentUser;
    if (fbUser != null) {
      try {
        final profile = await _fireStore.getUserProfile(fbUser.uid);
        if (profile != null) return profile;
      } catch (e) {
        DLog.error("Firestore getProfile error: $e");
      }
      final suffix = fbUser.uid.length >= 6
          ? fbUser.uid.substring(0, 6)
          : fbUser.uid;
      return User(
        id: fbUser.uid,
        username: fbUser.displayName ??
            (fbUser.isAnonymous
                ? 'guest_$suffix'
                : fbUser.email?.split('@').first),
        email: fbUser.email,
        avatarUrl: fbUser.photoURL,
      );
    }
    return null;
  }

  @override
  Future<User?> updateProfile(User user) async {
    await _fireStore.saveUserProfile(user);
    return user;
  }

  @override
  Future<bool> logout() async {
    await _authService.signOut();
    return true;
  }
}

/// Fallback implementation cho môi trường Testing hoặc Decoupled
class NoOpAuthRepos implements IAuthRepos {
  const NoOpAuthRepos();

  @override
  Future<User?> login(String username, String password) async => null;

  @override
  Future<User?> signInWithGoogle() async => null;

  @override
  Future<User?> signInAnonymously() async => null;

  @override
  Future<User?> getProfile() async => null;

  @override
  Future<User?> updateProfile(User user) async => user;

  @override
  Future<bool> logout() async => true;
}
