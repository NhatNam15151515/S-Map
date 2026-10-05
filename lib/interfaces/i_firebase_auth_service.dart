import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:s_map/models/user.dart';

abstract class IFirebaseAuthService {
  fb.User? get currentUser;
  Future<User?> signInWithGoogle();
  Future<User?> signInAnonymously();
  Future<void> signOut();
}
