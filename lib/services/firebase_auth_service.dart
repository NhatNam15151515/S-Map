import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/firebase_options.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/services.dart';

class FirebaseAuthService implements IFirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (_) {
        try {
          await Firebase.initializeApp();
        } catch (e) {
          DLog.error("Firebase init fallback error: $e");
        }
      }
    }
  }

  fb.FirebaseAuth? get _auth {
    try {
      if (Firebase.apps.isNotEmpty) {
        return fb.FirebaseAuth.instance;
      }
    } catch (_) {}
    return null;
  }

  @override
  fb.User? get currentUser => _auth?.currentUser;

  /// Đăng nhập bằng tài khoản Google
  @override
  Future<User?> signInWithGoogle() async {
    try {
      await _ensureFirebaseInitialized();

      // 1. Reset phiên trước để luôn hiển thị modal chọn tài khoản Google
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      // Kích hoạt giao diện chọn tài khoản Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Người dùng hủy chọn
        return null;
      }

      // 2. Lấy thông tin xác thực từ request (tokens)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      User appUser = User(
        id: googleUser.id,
        username: googleUser.displayName ?? googleUser.email.split('@').first,
        email: googleUser.email,
        avatarUrl: googleUser.photoUrl,
      );

      // 3. Đăng nhập Firebase Auth nếu có thể
      if (_auth != null) {
        try {
          final fb.AuthCredential credential = fb.GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          final fb.UserCredential userCredential = await _auth!.signInWithCredential(credential);
          final fb.User? firebaseUser = userCredential.user;

          if (firebaseUser != null) {
            appUser = User(
              id: firebaseUser.uid,
              username: firebaseUser.displayName ?? appUser.username,
              email: firebaseUser.email ?? appUser.email,
              avatarUrl: firebaseUser.photoURL ?? appUser.avatarUrl,
            );
          }
        } catch (fbAuthErr) {
          DLog.error("Firebase Auth credential error (dùng Google profile fallback): $fbAuthErr");
        }
      }

      // 4. Lưu/Cập nhật thông tin người dùng lên Cloud Firestore (không chặn luồng đăng nhập nếu Firestore lỗi quyền/mạng)
      try {
        await FireStoreService.instance.saveUserProfile(appUser);
      } catch (fsErr) {
        DLog.error("Không thể lưu profile lên Cloud Firestore: $fsErr");
      }
      return appUser;
    } catch (e) {
      DLog.error("Lỗi Google Sign-In: $e");
      rethrow;
    }
  }

  /// Đăng nhập ẩn danh (Anonymous Sign-In)
  @override
  Future<User?> signInAnonymously() async {
    try {
      await _ensureFirebaseInitialized();

      if (_auth != null) {
        final fb.UserCredential userCredential = await _auth!.signInAnonymously();
        final fb.User? firebaseUser = userCredential.user;

        if (firebaseUser != null) {
          final suffix = firebaseUser.uid.length >= 6
              ? firebaseUser.uid.substring(0, 6)
              : firebaseUser.uid;
          final user = User(
            id: firebaseUser.uid,
            username: 'Khách_$suffix',
          );

          try {
            await FireStoreService.instance.saveUserProfile(user);
          } catch (fsErr) {
            DLog.error("Không thể lưu anonymous profile lên Cloud Firestore: $fsErr");
          }
          return user;
        }
      }

      // Fallback offline user
      return User(
        id: 'anon_${DateTime.now().millisecondsSinceEpoch}',
        username: 'Khách_offline',
      );
    } catch (e) {
      DLog.error("Lỗi đăng nhập ẩn danh: $e");
      rethrow;
    }
  }

  /// Đăng xuất
  @override
  Future<void> signOut() async {
    await Future.wait([
      if (_auth != null) _auth!.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}
