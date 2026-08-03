import '../../repositories/auth_repository.dart';

/// Use case: enable / disable biometric unlock.
class ToggleBiometric {
  final AuthRepository repository;

  const ToggleBiometric(this.repository);

  Future<void> call(bool enabled) {
    return repository.setBiometricEnabled(enabled);
  }
}
