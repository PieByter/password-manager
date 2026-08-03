import '../../repositories/auth_repository.dart';

/// Use case: verify a master password (login).
class VerifyMasterPassword {
  final AuthRepository repository;

  const VerifyMasterPassword(this.repository);

  /// Returns `true` if the password matches the stored hash.
  Future<bool> call(String password) {
    return repository.verifyMasterPassword(password);
  }
}
