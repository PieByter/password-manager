import '../entities/password_entry.dart';

/// Repository interface (abstraction) for the encrypted vault.
///
/// Implementation: `data/repositories/vault_repository_impl.dart`.
///
/// The domain only knows "load entries" / "save entries" — encryption,
/// JSON mapping and secure storage are data-layer concerns hidden behind
/// this interface.
abstract class VaultRepository {
  /// Loads and decrypts all entries.
  /// Returns an empty list if no vault exists yet.
  /// Throws if the master password is wrong or data is corrupt.
  Future<List<PasswordEntry>> loadVault(String masterPassword);

  /// Encrypts and persists all entries.
  Future<void> saveVault(List<PasswordEntry> entries, String masterPassword);
}
