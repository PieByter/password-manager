import '../../repositories/auth_repository.dart';

/// Use case: create a master password (first-time setup).
///
/// Salt generation + hashing happen inside the repository implementation —
/// the domain only expresses WHAT must happen, not HOW.
class CreateMasterPassword {
  final AuthRepository repository;

  const CreateMasterPassword(this.repository);

  /// Throws if saving fails.
  Future<void> call(String password) {
    return repository.createMasterPassword(password);
  }
}
