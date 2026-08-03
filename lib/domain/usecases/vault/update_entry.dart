import '../../entities/password_entry.dart';
import '../../repositories/vault_repository.dart';

/// Input data for [UpdateEntry].
class UpdateEntryParams {
  final String masterPassword;
  final String id;
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;
  final String? totpSecret;
  final bool clearTotp;

  const UpdateEntryParams({
    required this.masterPassword,
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    this.url = '',
    this.notes = '',
    this.totpSecret,
    this.clearTotp = false,
  });
}

/// Use case: update an existing entry and persist the vault.
class UpdateEntry {
  final VaultRepository repository;

  const UpdateEntry(this.repository);

  /// Returns the updated entry list. If the entry is not found,
  /// the list is returned unchanged.
  Future<List<PasswordEntry>> call(UpdateEntryParams params) async {
    final entries = await repository.loadVault(params.masterPassword);
    final index = entries.indexWhere((e) => e.id == params.id);
    if (index == -1) return entries;

    entries[index] = entries[index].copyWith(
      title: params.title,
      username: params.username,
      password: params.password,
      url: params.url,
      notes: params.notes,
      totpSecret: params.totpSecret,
      clearTotp: params.clearTotp,
      updatedAt: DateTime.now(),
    );

    await repository.saveVault(entries, params.masterPassword);
    return entries;
  }
}
