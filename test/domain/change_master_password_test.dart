import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/domain/entities/password_entry.dart';
import 'package:password_manager/domain/repositories/auth_repository.dart';
import 'package:password_manager/domain/repositories/vault_repository.dart';
import 'package:password_manager/domain/usecases/auth/change_master_password.dart';

class _FakeAuthRepository implements AuthRepository {
  String _password;
  bool failChange = false;
  int cacheClears = 0;
  String? biometricPassword;
  bool biometricEnabled = false;

  _FakeAuthRepository(this._password);

  @override
  Future<bool> hasMasterPassword() async => true;

  @override
  Future<void> createMasterPassword(String password) async {
    _password = password;
  }

  @override
  Future<bool> verifyMasterPassword(String password) async =>
      password == _password;

  @override
  Future<void> changeMasterPassword(String newPassword) async {
    if (failChange) throw StateError('verifier write failed');
    _password = newPassword;
  }

  @override
  Future<bool> isBiometricAvailable() async => false;

  @override
  Future<bool> isBiometricEnabled() async => biometricEnabled;

  @override
  Future<void> setBiometricEnabled(bool enabled) async {
    biometricEnabled = enabled;
  }

  @override
  Future<void> saveBiometricPassword(String password) async {
    biometricPassword = password;
  }

  @override
  Future<String?> readBiometricPassword() async => biometricPassword;

  @override
  Future<void> deleteBiometricPassword() async {
    biometricPassword = null;
  }

  @override
  Future<bool> authenticateWithBiometrics() async => false;

  @override
  void clearSessionCache() {
    cacheClears++;
  }
}

class _FakeVaultRepository implements VaultRepository {
  String _password;
  List<PasswordEntry> entries;
  bool failNextSave = false;

  _FakeVaultRepository(this._password, this.entries);

  void _assertPassword(String password) {
    if (password != _password) {
      throw const FormatException('invalid password');
    }
  }

  @override
  Future<List<PasswordEntry>> loadVault(String masterPassword) async {
    _assertPassword(masterPassword);
    return List.of(entries);
  }

  @override
  Future<void> saveVault(
    List<PasswordEntry> entries,
    String masterPassword,
  ) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('disk full');
    }
    _password = masterPassword;
    this.entries = List.of(entries);
  }
}

void main() {
  final entry = PasswordEntry(
    id: 'entry-1',
    title: 'GitHub',
    username: 'octocat',
    password: 'secret',
  );

  late _FakeAuthRepository auth;
  late _FakeVaultRepository vault;
  late ChangeMasterPassword useCase;

  setUp(() {
    auth = _FakeAuthRepository('old-password-123');
    vault = _FakeVaultRepository('old-password-123', [entry]);
    useCase = ChangeMasterPassword(
      authRepository: auth,
      vaultRepository: vault,
    );
  });

  test('re-encrypts the vault and replaces the verifier', () async {
    final result = await useCase(
      oldPassword: 'old-password-123',
      newPassword: 'new-password-456',
    );

    expect(result, isTrue);
    expect(await auth.verifyMasterPassword('new-password-456'), isTrue);
    expect(await auth.verifyMasterPassword('old-password-123'), isFalse);
    expect((await vault.loadVault('new-password-456')).single.title, 'GitHub');
    expect(
      () => vault.loadVault('old-password-123'),
      throwsA(isA<FormatException>()),
    );
    expect(auth.cacheClears, greaterThan(0));
  });

  test('rejects a wrong old password without changing anything', () async {
    final result = await useCase(
      oldPassword: 'wrong-password',
      newPassword: 'new-password-456',
    );

    expect(result, isFalse);
    expect(await auth.verifyMasterPassword('old-password-123'), isTrue);
    expect((await vault.loadVault('old-password-123')).single.id, 'entry-1');
  });

  test('rejects reusing the same password', () async {
    final result = await useCase(
      oldPassword: 'old-password-123',
      newPassword: 'old-password-123',
    );

    expect(result, isFalse);
    expect(await auth.verifyMasterPassword('old-password-123'), isTrue);
  });

  test('keeps the old vault when re-encryption fails', () async {
    vault.failNextSave = true;

    await expectLater(
      useCase(oldPassword: 'old-password-123', newPassword: 'new-password-456'),
      throwsA(isA<StateError>()),
    );

    expect(await auth.verifyMasterPassword('old-password-123'), isTrue);
    expect((await vault.loadVault('old-password-123')).single.id, 'entry-1');
  });

  test('rolls back the vault when the verifier cannot be written', () async {
    auth.failChange = true;

    await expectLater(
      useCase(oldPassword: 'old-password-123', newPassword: 'new-password-456'),
      throwsA(isA<StateError>()),
    );

    expect(await auth.verifyMasterPassword('old-password-123'), isTrue);
    expect((await vault.loadVault('old-password-123')).single.id, 'entry-1');
  });
}
