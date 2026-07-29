// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/encryption/encryption_service.dart';
import '../../../core/storage/secure_storage_service.dart';

enum AuthStatus { uninitialized, needsSetup, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final SecureStorageService _storage;
  final EncryptionService _encryption;
  final LocalAuthentication _localAuth;

  AuthStatus _status = AuthStatus.uninitialized;
  String? _masterPassword;
  String? _salt;
  bool _isBiometricAvailable = false;
  bool _biometricEnabled = false;

  AuthProvider({
    required SecureStorageService storage,
    EncryptionService? encryption,
    LocalAuthentication? localAuth,
  }) : _storage = storage,
       _encryption = encryption ?? EncryptionService(),
       _localAuth = localAuth ?? LocalAuthentication();

  AuthStatus get status => _status;
  bool get isBiometricAvailable => _isBiometricAvailable;
  bool get biometricEnabled => _biometricEnabled;
  String? get masterPassword => _masterPassword;
  String? get salt => _salt;

  /// Initialize the auth provider — check if master password exists
  Future<void> initialize() async {
    try {
      _isBiometricAvailable =
          await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      _biometricEnabled = await _storage.isBiometricEnabled();

      final hasPassword = await _storage.hasMasterPassword();
      _status = hasPassword
          ? AuthStatus.unauthenticated
          : AuthStatus.needsSetup;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Create a new master password (first-time setup)
  Future<bool> createMasterPassword(String password) async {
    try {
      final salt = _encryption.generateSalt();
      final hash = _encryption.hashMasterPassword(password, salt);
      await _storage.saveMasterPasswordHash(hash, salt);

      _masterPassword = password;
      _salt = salt;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error creating master password: $e');
      return false;
    }
  }

  /// Verify master password (login)
  Future<bool> login(String password) async {
    try {
      final salt = await _storage.getMasterPasswordSalt();
      final storedHash = await _storage.getMasterPasswordHash();
      if (salt == null || storedHash == null) return false;

      final hash = _encryption.hashMasterPassword(password, salt);
      if (hash != storedHash) return false;

      _masterPassword = password;
      _salt = salt;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error logging in: $e');
      return false;
    }
  }

  /// Authenticate using biometrics
  Future<bool> loginWithBiometrics() async {
    if (!_isBiometricAvailable) return false;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock your password vault',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (!authenticated) return false;

      // We still need the master password to decrypt the vault,
      // so this just marks that biometrics passed.
      // The actual master password will be prompted separately.
      return true;
    } catch (e) {
      debugPrint('Biometric error: $e');
      return false;
    }
  }

  /// Toggle biometric unlock
  Future<void> toggleBiometric(bool enabled) async {
    _biometricEnabled = enabled;
    await _storage.setBiometricEnabled(enabled);
    notifyListeners();
  }

  /// Logout — clear in-memory credentials
  void logout() {
    _masterPassword = null;
    _salt = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
