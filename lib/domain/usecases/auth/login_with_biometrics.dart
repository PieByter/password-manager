import '../../repositories/auth_repository.dart';

/// Outcome of a biometric unlock attempt.
///
/// Distinguishes "the user cancelled / failed the prompt" from "the prompt
/// succeeded but no credential is stored", so the provider can clean up a
/// stale biometric flag without disabling biometrics on a simple cancel.
class BiometricLoginResult {
  final bool authenticated;
  final String? password;

  const BiometricLoginResult({required this.authenticated, this.password});
}

/// Use case: unlock via biometrics.
///
/// Returns the master password stored behind the biometric gate, or a failed
/// result when biometrics are disabled/cancelled. The caller must not read the
/// credential without running this use case first.
class LoginWithBiometrics {
  final AuthRepository repository;

  const LoginWithBiometrics(this.repository);

  Future<BiometricLoginResult> call() async {
    if (!await repository.isBiometricEnabled()) {
      return const BiometricLoginResult(authenticated: false);
    }

    final authenticated = await repository.authenticateWithBiometrics();
    if (!authenticated) {
      return const BiometricLoginResult(authenticated: false);
    }

    return BiometricLoginResult(
      authenticated: true,
      password: await repository.readBiometricPassword(),
    );
  }
}
