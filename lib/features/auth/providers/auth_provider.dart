// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import '../../../domain/usecases/auth/change_master_password.dart';
import '../../../domain/usecases/auth/create_master_password.dart';
import '../../../domain/usecases/auth/initialize_auth.dart';
import '../../../domain/usecases/auth/lock_session.dart';
import '../../../domain/usecases/auth/login_with_biometrics.dart';
import '../../../domain/usecases/auth/toggle_biometric.dart';
import '../../../domain/usecases/auth/verify_master_password.dart';

enum AuthStatus { uninitialized, needsSetup, authenticated, unauthenticated }

/// Presentation-layer state manager for authentication.
///
/// Clean Architecture: this class only maps UI actions to use cases and
/// holds UI state. It no longer touches storage/encryption/platform —
/// those are data-layer concerns reached through the use cases.
class AuthProvider extends ChangeNotifier {
  final InitializeAuth _initializeAuth;
  final CreateMasterPassword _createMasterPassword;
  final VerifyMasterPassword _verifyMasterPassword;
  final LoginWithBiometrics _loginWithBiometrics;
  final ToggleBiometric _toggleBiometric;
  final ChangeMasterPassword _changeMasterPassword;
  final LockSession _lockSession;

  AuthStatus _status = AuthStatus.uninitialized;
  String? _masterPassword;
  bool _isBiometricAvailable = false;
  bool _biometricEnabled = false;

  AuthProvider({
    required InitializeAuth initializeAuth,
    required CreateMasterPassword createMasterPassword,
    required VerifyMasterPassword verifyMasterPassword,
    required LoginWithBiometrics loginWithBiometrics,
    required ToggleBiometric toggleBiometric,
    required ChangeMasterPassword changeMasterPassword,
    required LockSession lockSession,
  }) : _initializeAuth = initializeAuth,
       _createMasterPassword = createMasterPassword,
       _verifyMasterPassword = verifyMasterPassword,
       _loginWithBiometrics = loginWithBiometrics,
       _toggleBiometric = toggleBiometric,
       _changeMasterPassword = changeMasterPassword,
       _lockSession = lockSession;

  AuthStatus get status => _status;
  bool get isBiometricAvailable => _isBiometricAvailable;
  bool get biometricEnabled => _biometricEnabled;
  String? get masterPassword => _masterPassword;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Initialize the auth provider — check if master password exists.
  Future<void> initialize() async {
    try {
      final info = await _initializeAuth();
      _isBiometricAvailable = info.biometricAvailable;
      _biometricEnabled = info.biometricEnabled;
      _status = info.hasMasterPassword
          ? AuthStatus.unauthenticated
          : AuthStatus.needsSetup;
    } catch (e) {
      debugPrint('Error initializing auth: $e');
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Create a new master password (first-time setup).
  Future<bool> createMasterPassword(String password) async {
    try {
      await _createMasterPassword(password);
      _masterPassword = password;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error creating master password: $e');
      return false;
    }
  }

  /// Verify master password (login).
  Future<bool> login(String password) async {
    try {
      final valid = await _verifyMasterPassword(password);
      if (!valid) return false;

      _masterPassword = password;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error logging in: $e');
      return false;
    }
  }

  /// Authenticate using biometrics and unlock the vault with the stored
  /// master password. No second password prompt is needed.
  Future<bool> loginWithBiometrics() async {
    try {
      final result = await _loginWithBiometrics();
      if (!result.authenticated) return false;

      final password = result.password;
      if (password == null || password.isEmpty) {
        // The biometric prompt succeeded but the credential is missing.
        // Remove the stale flag so the UI stops offering a broken option.
        await _toggleBiometric(false);
        _biometricEnabled = false;
        notifyListeners();
        return false;
      }

      // Defensive check: the stored credential could be stale if the master
      // password was changed while biometrics were enabled.
      final valid = await _verifyMasterPassword(password);
      if (!valid) {
        await _toggleBiometric(false);
        _biometricEnabled = false;
        notifyListeners();
        return false;
      }

      _masterPassword = password;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error logging in with biometrics: $e');
      return false;
    }
  }

  /// Enable or disable biometric unlock.
  ///
  /// Enabling requires an unlocked session so the master password can be
  /// stored behind the biometric gate.
  Future<bool> toggleBiometric(bool enabled) async {
    try {
      await _toggleBiometric(
        enabled,
        masterPassword: enabled ? _masterPassword : null,
      );
      _biometricEnabled = enabled;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error toggling biometrics: $e');
      return false;
    }
  }

  /// Rotate the master password. Returns `false` for a wrong old password.
  Future<bool> changeMasterPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final success = await _changeMasterPassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      if (!success) return false;

      _masterPassword = newPassword;
      if (_biometricEnabled) {
        try {
          await _toggleBiometric(true, masterPassword: newPassword);
        } catch (e) {
          debugPrint('Failed to update biometric credential: $e');
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error changing master password: $e');
      return false;
    }
  }

  /// Logout — clear in-memory credentials and derived keys.
  void logout() {
    _masterPassword = null;
    _status = AuthStatus.unauthenticated;
    _lockSession();
    notifyListeners();
  }
}
