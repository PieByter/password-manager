import 'package:uuid/uuid.dart';

import '../../entities/password_entry.dart';
import '../../repositories/vault_repository.dart';

/// Input data for [AddEntry].
///
/// A params object keeps the `call()` signature readable when a use case
/// needs many arguments.
class AddEntryParams {
  final String masterPassword;
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;
  final String? totpSecret;

  const AddEntryParams({
    required this.masterPassword,
    required this.title,
    required this.username,
    required this.password,
    this.url = '',
    this.notes = '',
    this.totpSecret,
  });
}

/// Use case: add a new password entry and persist the vault.
///
/// Business logic that used to live in the provider:
/// generating the ID, inserting at the top, saving.
class AddEntry {
  final VaultRepository repository;

  const AddEntry(this.repository);

  /// Returns the updated entry list (source of truth = storage via repository).
  Future<List<PasswordEntry>> call(AddEntryParams params) async {
    final entries = await repository.loadVault(params.masterPassword);

    entries.insert(
      0,
      PasswordEntry(
        id: const Uuid().v4(),
        title: params.title,
        username: params.username,
        password: params.password,
        url: params.url,
        notes: params.notes,
        totpSecret: params.totpSecret,
      ),
    );

    await repository.saveVault(entries, params.masterPassword);
    return entries;
  }
}
