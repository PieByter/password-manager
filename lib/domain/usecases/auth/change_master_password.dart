import '../../repositories/auth_repository.dart';
import '../../repositories/vault_repository.dart';

/// Use case: rotate the master password without losing vault data.
///
/// Order of operations is deliberate:
/// 1. Verify the old password.
/// 2. Decrypt the vault with the old password.
/// 3. Re-encrypt and persist it with the new password.
/// 4. Only then replace the stored verifier.
///
/// If step 3 fails, the old verifier still opens the old vault. If step 4
/// fails, the vault is re-encrypted back with the old password before the
/// error is rethrown.
class ChangeMasterPassword {
  final AuthRepository authRepository;
  final VaultRepository vaultRepository;

  const ChangeMasterPassword({
    required this.authRepository,
    required this.vaultRepository,
  });

  /// Returns `false` when [oldPassword] is incorrect.
  Future<bool> call({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (oldPassword == newPassword) return false;

    final valid = await authRepository.verifyMasterPassword(oldPassword);
    if (!valid) return false;

    final entries = await vaultRepository.loadVault(oldPassword);

    // Never let the cache serve a key derived from the old password while
    // writing the new vault.
    authRepository.clearSessionCache();

    try {
      await vaultRepository.saveVault(entries, newPassword);
    } catch (_) {
      authRepository.clearSessionCache();
      rethrow;
    }

    try {
      await authRepository.changeMasterPassword(newPassword);
    } catch (_) {
      // Best-effort rollback: the verifier still belongs to the old password.
      authRepository.clearSessionCache();
      await vaultRepository.saveVault(entries, oldPassword);
      authRepository.clearSessionCache();
      rethrow;
    }

    return true;
  }
}
