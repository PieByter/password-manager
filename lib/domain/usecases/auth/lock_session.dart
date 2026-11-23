import '../../repositories/auth_repository.dart';

/// Use case: drop all in-memory session secrets when the vault locks.
class LockSession {
  final AuthRepository repository;

  const LockSession(this.repository);

  void call() {
    repository.clearSessionCache();
  }
}
