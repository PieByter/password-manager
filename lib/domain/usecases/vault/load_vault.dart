import '../../entities/password_entry.dart';
import '../../repositories/vault_repository.dart';

/// Use case: load and decrypt the whole vault.
class LoadVault {
  final VaultRepository repository;

  const LoadVault(this.repository);

  Future<List<PasswordEntry>> call(String masterPassword) {
    return repository.loadVault(masterPassword);
  }
}
