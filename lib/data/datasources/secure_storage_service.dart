import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local datasource — the only place that touches the platform's secure
/// storage (Android Keystore / iOS Keychain).
///
/// This is a framework detail, so it lives in the DATA layer and is used
/// by repository implementations. Domain & presentation never import it.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService() : _storage = const FlutterSecureStorage();

  // Key constants
  static const _keySalt = 'master_password_salt';
  static const _keyHash = 'master_password_hash';
  static const _vaultData = 'vault_encrypted_data';
  static const _biometricEnabled = 'biometric_enabled';
  static const _biometricPassword = 'biometric_master_password';

  // --- Master Password ---

  Future<bool> hasMasterPassword() async {
    final hash = await _storage.read(key: _keyHash);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> saveMasterPasswordHash(String hash, String salt) async {
    await _storage.write(key: _keyHash, value: hash);
    await _storage.write(key: _keySalt, value: salt);
  }

  Future<String?> getMasterPasswordHash() async {
    return await _storage.read(key: _keyHash);
  }

  Future<String?> getMasterPasswordSalt() async {
    return await _storage.read(key: _keySalt);
  }

  // --- Vault Data (encrypted JSON blob) ---

  Future<void> saveVault(String encryptedJson) async {
    await _storage.write(key: _vaultData, value: encryptedJson);
  }

  Future<String?> loadVault() async {
    return await _storage.read(key: _vaultData);
  }

  // --- Biometric setting + wrapped credential ---

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabled, value: enabled.toString());
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabled);
    return value == 'true';
  }

  /// Stores the master password for biometric unlock.
  ///
  /// The value is only read after a successful `local_auth` prompt. See the
  /// PRD (FR-03) for the platform security limitations of this approach.
  Future<void> saveBiometricPassword(String password) async {
    await _storage.write(key: _biometricPassword, value: password);
  }

  Future<String?> readBiometricPassword() async {
    return _storage.read(key: _biometricPassword);
  }

  Future<void> deleteBiometricPassword() async {
    await _storage.delete(key: _biometricPassword);
  }

  // --- Clear all data ---

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
