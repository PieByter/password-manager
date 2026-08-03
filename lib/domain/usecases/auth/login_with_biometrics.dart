import '../../repositories/auth_repository.dart';

/// Use case: unlock via biometrics (system prompt).
class LoginWithBiometrics {
  final AuthRepository repository;

  const LoginWithBiometrics(this.repository);

  Future<bool> call() {
    return repository.authenticateWithBiometrics();
  }
}
