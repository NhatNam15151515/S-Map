/// Interface for lightweight, non-sensitive local key-value storage.
///
/// Concrete implementation: [AppSharedPreferences] in services/flutter_secure.dart.
/// Declared here so [commons_logic] layer (cubits, mixins) can depend on the
/// abstraction instead of the concrete service.
abstract class ISharedPreferences {
  /// Returns true if this is the first time the app has been installed
  /// (used to clear secure storage on fresh installs).
  Future<bool> get1stInstall();

  /// Marks the first-install flag as consumed so it won't trigger again.
  Future<void> save1stInstall();
}
