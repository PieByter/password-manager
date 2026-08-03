// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import '../../../domain/usecases/auth/create_master_password.dart';
import '../../../domain/usecases/auth/initialize_auth.dart';
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
  }) : _initializeAuth = initializeAuth,
       _createMasterPassword = createMasterPassword,
       _verifyMasterPassword = verifyMasterPassword,
       _loginWithBiometrics = loginWithBiometrics,
       _toggleBiometric = toggleBiometric;

  AuthStatus get status => _status;
  bool get isBiometricAvailable => _isBiometricAvailable;
  bool get biometricEnabled => _biometricEnabled;
  String? get masterPassword => _masterPassword;

  /// Initialize the auth provider — check if master password exists
  Future<void> initialize() async {
    try {
      final info = await _initializeAuth();
      _isBiometricAvailable = info.biometricAvailable;
      _biometricEnabled = info.biometricEnabled;
      _status = info.hasMasterPassword
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

  /// Verify master password (login)
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

  /// Authenticate using biometrics
  Future<bool> loginWithBiometrics() {
    return _loginWithBiometrics();
  }

  /// Toggle biometric unlock
  Future<void> toggleBiometric(bool enabled) async {
    _biometricEnabled = enabled;
    await _toggleBiometric(enabled);
    notifyListeners();
  }

  /// Logout — clear in-memory credentials
  void logout() {
    _masterPassword = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
