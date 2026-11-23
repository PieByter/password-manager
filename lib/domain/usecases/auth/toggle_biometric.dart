import '../../repositories/auth_repository.dart';

/// Use case: enable / disable biometric unlock.
///
/// Enabling requires the current master password so it can be stored behind
/// the biometric gate. Disabling removes the stored credential.
class ToggleBiometric {
  final AuthRepository repository;

  const ToggleBiometric(this.repository);

  Future<void> call(bool enabled, {String? masterPassword}) async {
    if (enabled) {
      if (masterPassword == null || masterPassword.isEmpty) {
        throw ArgumentError('Master password is required to enable biometrics');
      }

      // Confirm the biometric factor before storing the credential.
      final authenticated = await repository.authenticateWithBiometrics();
      if (!authenticated) {
        throw StateError('Biometric authentication failed');
      }

      await repository.saveBiometricPassword(masterPassword);
    } else {
      await repository.deleteBiometricPassword();
    }

    await repository.setBiometricEnabled(enabled);
  }
}
