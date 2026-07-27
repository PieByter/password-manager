import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  // Key constants
  static const _keySalt = 'master_password_salt';
  static const _keyHash = 'master_password_hash';
  static const _vaultData = 'vault_encrypted_data';
  static const _biometricEnabled = 'biometric_enabled';

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

  // --- Biometric setting ---

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabled, value: enabled.toString());
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabled);
    return value == 'true';
  }

  // --- Clear all data ---

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
