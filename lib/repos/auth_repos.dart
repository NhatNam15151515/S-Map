import 'package:s_map/models/user.dart';
import 'package:s_map/services/firebase_auth_service.dart';
import 'package:s_map/services/firebase_firestore_service.dart';

abstract class AuthRepos {
  Future<User?> login(String username, String password);
  Future<User?> getProfile();
  Future<User?> updateProfile(User user);
  Future<bool> logout();
}

class AuthReposImpl implements AuthRepos {
  final FireStoreService _fireStore = FireStoreService();

  @override
  Future<User?> login(String username, String password) async {
    return User(
      username: username.isNotEmpty ? username : "Người dùng S-Map",
    );
  }

  @override
  Future<User?> getProfile() async {
    return User(
      username: "Người dùng S-Map",
    );
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
