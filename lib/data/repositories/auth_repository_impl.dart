// ignore_for_file: prefer_initializing_formals

import 'package:local_auth/local_auth.dart';

import '../../domain/repositories/auth_repository.dart';
import '../datasources/secure_storage_service.dart';
import '../encryption/encryption_service.dart';

/// Concrete implementation of [AuthRepository] (data layer).
///
/// Knows HOW to fulfill the contract: hashing, salt, secure storage,
/// biometric plugin. Domain use cases only see the [AuthRepository]
/// interface and never these details.
class AuthRepositoryImpl implements AuthRepository {
  final SecureStorageService _storage;
  final EncryptionService _encryption;
  final LocalAuthentication _localAuth;

  AuthRepositoryImpl({
    required SecureStorageService storage,
    required EncryptionService encryption,
    LocalAuthentication? localAuth,
  }) : _storage = storage,
       _encryption = encryption,
       _localAuth = localAuth ?? LocalAuthentication();

  @override
  Future<bool> hasMasterPassword() {
    return _storage.hasMasterPassword();
  }

  @override
  Future<void> createMasterPassword(String password) async {
    final salt = _encryption.generateSalt();
    final hash = _encryption.hashMasterPassword(password, salt);
    await _storage.saveMasterPasswordHash(hash, salt);
  }

  @override
  Future<bool> verifyMasterPassword(String password) async {
    final salt = await _storage.getMasterPasswordSalt();
    final storedHash = await _storage.getMasterPasswordHash();
    if (salt == null || storedHash == null) return false;

    return _encryption.verifyMasterPassword(password, salt, storedHash);
  }

  @override
  Future<void> changeMasterPassword(String newPassword) async {
    final salt = await _storage.getMasterPasswordSalt();
    if (salt == null) {
      throw StateError('Master password salt not found');
    }

    final hash = _encryption.hashMasterPassword(newPassword, salt);
    await _storage.saveMasterPasswordHash(hash, salt);
    _encryption.clearKeyCache();
  }

  @override
  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (e) {
      // Unsupported platform or missing plugin: biometrics are optional.
      return false;
    }
  }

  @override
  Future<bool> isBiometricEnabled() {
    return _storage.isBiometricEnabled();
  }

  @override
  Future<void> setBiometricEnabled(bool enabled) {
    return _storage.setBiometricEnabled(enabled);
  }

  @override
  Future<void> saveBiometricPassword(String password) {
    return _storage.saveBiometricPassword(password);
  }

  @override
  Future<String?> readBiometricPassword() {
    return _storage.readBiometricPassword();
  }

  @override
  Future<void> deleteBiometricPassword() {
    return _storage.deleteBiometricPassword();
  }

  @override
  Future<bool> authenticateWithBiometrics() async {
    if (!await isBiometricAvailable()) return false;

    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock your password vault',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      return false;
    }
  }

  @override
  void clearSessionCache() {
    _encryption.clearKeyCache();
  }
}
