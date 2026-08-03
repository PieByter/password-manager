/// Repository interface (abstraction) for authentication.
///
/// The domain layer defines the CONTRACT; the implementation lives in
/// `data/repositories/auth_repository_impl.dart`.
///
/// Why an interface? → **Dependency Inversion**: presentation depends on
/// this abstraction, not on the concrete implementation. That makes it easy
/// to swap implementations (e.g. in-memory fake for previews/tests).
abstract class AuthRepository {
  /// Whether a master password has been set up already.
  Future<bool> hasMasterPassword();

  /// Creates a master password: generates salt + hash internally
  /// and persists them. Throws if persistence fails.
  Future<void> createMasterPassword(String password);

  /// Returns `true` if [password] matches the stored hash.
  Future<bool> verifyMasterPassword(String password);

  /// Whether the device supports biometrics (fingerprint / face ID).
  Future<bool> isBiometricAvailable();

  Future<bool> isBiometricEnabled();

  Future<void> setBiometricEnabled(bool enabled);

  /// Shows the system biometric prompt. Returns `true` on success.
  Future<bool> authenticateWithBiometrics();
}
