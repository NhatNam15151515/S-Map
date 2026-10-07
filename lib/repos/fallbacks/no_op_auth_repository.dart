import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

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
