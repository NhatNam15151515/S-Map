import 'package:s_map/models/models.dart';

/// Interface for encrypted/secure local key-value storage.
///
/// Concrete implementation: [AppSecureStorage] in services/flutter_secure.dart.
/// Declared here so [commons_logic] layer (cubits, mixins) can depend on the
/// abstraction instead of the concrete service.
abstract class ISecureStorage {
  /// Save an authenticated user's profile to secure storage.
  Future<void> saveProfile(User user);

  /// Retrieve the stored user profile, or null if not found / invalid.
  Future<User?> getStoredProfile();

  /// Save the authentication token to secure storage.
  Future<void> saveAuthToken(String token);

  /// Retrieve the stored authentication token.
  Future<String?> getStoredAuthToken();

  /// Persist whether the user has opted-in for local auth (FaceID/Fingerprint).
  Future<void> saveReqAuth(bool value);

  /// Read whether the user has opted-in for local auth.
  Future<bool> getReqAuth();

  /// Clear all auth-related keys on logout.
  Future<void> onLogOutClear();
}
