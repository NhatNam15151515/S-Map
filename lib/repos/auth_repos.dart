import 'package:s_map/interfaces/i_auth_repos.dart';
import 'package:s_map/models/user.dart';
import 'package:s_map/services/firebase_auth_service.dart';
import 'package:s_map/services/firebase_firestore_service.dart';

// Backward compatibility alias
typedef AuthRepos = IAuthRepos;

class AuthReposImpl implements IAuthRepos {
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
