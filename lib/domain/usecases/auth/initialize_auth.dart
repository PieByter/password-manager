import '../../repositories/auth_repository.dart';

/// Result of the app-startup check performed by [InitializeAuth].
class AuthInitInfo {
  final bool hasMasterPassword;
  final bool biometricAvailable;
  final bool biometricEnabled;

  const AuthInitInfo({
    required this.hasMasterPassword,
    required this.biometricAvailable,
    required this.biometricEnabled,
  });
}

/// Use case: check app state on startup.
///
/// A use case holds ONE piece of business logic. The provider (presentation)
/// calls it and maps the result to UI state — it never talks to storage
/// or platform plugins directly.
class InitializeAuth {
  final AuthRepository repository;

  const InitializeAuth(this.repository);

  Future<AuthInitInfo> call() async {
    final hasMasterPassword = await repository.hasMasterPassword();
    final biometricAvailable = await repository.isBiometricAvailable();
    final biometricEnabled = await repository.isBiometricEnabled();
    return AuthInitInfo(
      hasMasterPassword: hasMasterPassword,
      biometricAvailable: biometricAvailable,
      biometricEnabled: biometricEnabled,
    );
  }
}
