import 'package:s_map/models/user.dart';

abstract class IAuthRepos {
  Future<User?> login(String username, String password);
  Future<User?> signInWithGoogle();
  Future<User?> signInAnonymously();
  Future<User?> getProfile();
  Future<User?> updateProfile(User user);
  Future<bool> logout();
}
