import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/services.dart';

// Backward compatibility alias
typedef AuthRepos = IAuthRepos;

class AuthReposImpl implements IAuthRepos {
  final FireStoreService _fireStore = FireStoreService();

  @override
  Future<User?> login(String username, String password) async {
    return User(
      username: username.trim(),
    );
  }

  @override
  Future<User?> signInWithGoogle() async {
    return await FirebaseAuthService.instance.signInWithGoogle();
  }

  @override
  Future<User?> signInAnonymously() async {
    return await FirebaseAuthService.instance.signInAnonymously();
  }

  @override
  Future<User?> getProfile() async {
    return User();
  }

  @override
  Future<User?> updateProfile(User user) async {
    await _fireStore.saveUserProfile(user);
    return user;
  }

  @override
  Future<bool> logout() async {
    await FirebaseAuthService.instance.signOut();
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
