import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/domain/repositories/auth_repository.dart';
import 'package:password_manager/domain/usecases/auth/initialize_auth.dart';

class _FakeAuthRepository implements AuthRepository {
  final bool hasPassword;
  final bool biometricsThrow;

  _FakeAuthRepository({
    required this.hasPassword,
    this.biometricsThrow = false,
  });

  @override
  Future<bool> hasMasterPassword() async => hasPassword;

  @override
  Future<bool> isBiometricAvailable() async {
    if (biometricsThrow) throw StateError('plugin unavailable');
    return true;
  }

  @override
  Future<bool> isBiometricEnabled() async {
    if (biometricsThrow) throw StateError('plugin unavailable');
    return true;
  }

  @override
  Future<void> createMasterPassword(String password) async {}

  @override
  Future<bool> verifyMasterPassword(String password) async => false;

  @override
  Future<void> changeMasterPassword(String newPassword) async {}

  @override
  Future<void> setBiometricEnabled(bool enabled) async {}

  @override
  Future<void> saveBiometricPassword(String password) async {}

  @override
  Future<String?> readBiometricPassword() async => null;

  @override
  Future<void> deleteBiometricPassword() async {}

  @override
  Future<bool> authenticateWithBiometrics() async => false;

  @override
  void clearSessionCache() {}
}

void main() {
  test(
    'first-time setup still works when biometrics are unavailable',
    () async {
      final info = await InitializeAuth(
        _FakeAuthRepository(hasPassword: false, biometricsThrow: true),
      )();

      expect(info.hasMasterPassword, isFalse);
      expect(info.biometricAvailable, isFalse);
      expect(info.biometricEnabled, isFalse);
    },
  );

  test(
    'existing vault still reports password presence on plugin failure',
    () async {
      final info = await InitializeAuth(
        _FakeAuthRepository(hasPassword: true, biometricsThrow: true),
      )();

      expect(info.hasMasterPassword, isTrue);
      expect(info.biometricAvailable, isFalse);
      expect(info.biometricEnabled, isFalse);
    },
  );

  test('biometric state is reported when available', () async {
    final info = await InitializeAuth(_FakeAuthRepository(hasPassword: true))();

    expect(info.hasMasterPassword, isTrue);
    expect(info.biometricAvailable, isTrue);
    expect(info.biometricEnabled, isTrue);
  });
}
