import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/domain/entities/password_entry.dart';
import 'package:password_manager/domain/repositories/vault_repository.dart';
import 'package:password_manager/domain/usecases/vault/add_entry.dart';
import 'package:password_manager/domain/usecases/vault/delete_entry.dart';
import 'package:password_manager/domain/usecases/vault/load_vault.dart';
import 'package:password_manager/domain/usecases/vault/update_entry.dart';
import 'package:password_manager/features/vault/providers/vault_provider.dart';

class _FakeVaultRepository implements VaultRepository {
  List<PasswordEntry> entries = const [];
  int loadCount = 0;
  bool failLoad = false;

  @override
  Future<List<PasswordEntry>> loadVault(String masterPassword) async {
    loadCount++;
    if (failLoad) throw const FormatException('corrupt vault');
    return List.of(entries);
  }

  @override
  Future<void> saveVault(
    List<PasswordEntry> entries,
    String masterPassword,
  ) async {
    this.entries = List.of(entries);
  }
}

void main() {
  late _FakeVaultRepository repository;
  late VaultProvider provider;

  setUp(() {
    repository = _FakeVaultRepository();
    provider = VaultProvider(
      loadVault: LoadVault(repository),
      addEntry: AddEntry(repository),
      updateEntry: UpdateEntry(repository),
      deleteEntry: DeleteEntry(repository),
    );
  });

  test('an empty vault is loaded once, not on every rebuild', () async {
    await provider.loadVault('password');

    expect(provider.hasLoaded, isTrue);
    expect(provider.allEntries, isEmpty);

    await provider.loadVault('password');
    expect(repository.loadCount, 1);
  });

  test('reset allows the next session to load again', () async {
    await provider.loadVault('password');
    provider.reset();

    expect(provider.hasLoaded, isFalse);
    expect(provider.allEntries, isEmpty);

    await provider.loadVault('password');
    expect(repository.loadCount, 2);
  });

  test('load errors set a message and do not retry automatically', () async {
    repository.failLoad = true;

    await provider.loadVault('password');

    expect(provider.hasLoaded, isTrue);
    expect(provider.errorMessage, isNotNull);

    await provider.loadVault('password');
    expect(repository.loadCount, 1);
  });

  test('force reload retries after an error', () async {
    repository.failLoad = true;
    await provider.loadVault('password');

    repository.failLoad = false;
    await provider.loadVault('password', force: true);

    expect(provider.errorMessage, isNull);
    expect(repository.loadCount, 2);
  });
}
