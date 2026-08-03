import '../../entities/password_entry.dart';
import '../../repositories/vault_repository.dart';

/// Use case: delete an entry and persist the vault.
class DeleteEntry {
  final VaultRepository repository;

  const DeleteEntry(this.repository);

  /// Returns the updated entry list.
  Future<List<PasswordEntry>> call({
    required String id,
    required String masterPassword,
  }) async {
    final entries = await repository.loadVault(masterPassword);
    entries.removeWhere((e) => e.id == id);
    await repository.saveVault(entries, masterPassword);
    return entries;
  }
}
