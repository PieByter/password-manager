// Preview-only file menggunakan Flutter Widget Preview NATIVE
// (anotasi @Preview dari Flutter SDK, didukung Flutter 3.36+ dan
// Dart extension 3.138+ — keduanya terpenuhi di proyek ini).
//
// Cara pakai:
//   1. Buka file ini di editor.
//   2. Ctrl+Shift+P → ketik "Flutter: Show Widget Preview" (atau klik
//      ikon Preview di pojok kanan atas editor).
//   3. Panel preview tampil di sidebar/editor.
//
// EntryScreen butuh AuthProvider & VaultProvider. Berkat Clean Architecture,
// kita cukup membuat FAKE REPOSITORY in-memory (mengimplementasikan interface
// domain) — tidak perlu menyentuh platform channel sama sekali, sehingga
// preview aman dan bebas crash.

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';

import '../domain/entities/password_entry.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/vault_repository.dart';
import '../domain/usecases/auth/create_master_password.dart';
import '../domain/usecases/auth/initialize_auth.dart';
import '../domain/usecases/auth/login_with_biometrics.dart';
import '../domain/usecases/auth/toggle_biometric.dart';
import '../domain/usecases/auth/verify_master_password.dart';
import '../domain/usecases/vault/add_entry.dart';
import '../domain/usecases/vault/delete_entry.dart';
import '../domain/usecases/vault/load_vault.dart';
import '../domain/usecases/vault/update_entry.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/entry/screens/entry_screen.dart';
import '../features/vault/providers/vault_provider.dart';

/// Entry point untuk preview native Flutter.
@Preview(name: 'Entry Screen', size: Size(420, 880))
Widget entryScreenPreview() => const EntryScreenPreview();

/// Fake auth repository — data disimpan di memory, tidak menyentuh
/// platform channel (aman untuk preview).
class FakeAuthRepository implements AuthRepository {
  final Map<String, String> _data = {};
  bool _biometricEnabled = false;

  @override
  Future<bool> hasMasterPassword() async => _data.containsKey('hash');

  @override
  Future<void> createMasterPassword(String password) async {
    _data['hash'] = password;
    _data['salt'] = 'fake-salt';
  }

  @override
  Future<bool> verifyMasterPassword(String password) async {
    return _data['hash'] == password;
  }

  @override
  Future<bool> isBiometricAvailable() async => false;

  @override
  Future<bool> isBiometricEnabled() async => _biometricEnabled;

  @override
  Future<void> setBiometricEnabled(bool enabled) async {
    _biometricEnabled = enabled;
  }

  @override
  Future<bool> authenticateWithBiometrics() async => false;
}

/// Fake vault repository — list disimpan di memory.
class FakeVaultRepository implements VaultRepository {
  final List<PasswordEntry> _entries = [];

  @override
  Future<List<PasswordEntry>> loadVault(String masterPassword) async {
    return List.of(_entries);
  }

  @override
  Future<void> saveVault(
    List<PasswordEntry> entries,
    String masterPassword,
  ) async {
    _entries
      ..clear()
      ..addAll(entries);
  }
}

/// Widget yang akan di-preview oleh extension.
class EntryScreenPreview extends StatelessWidget {
  const EntryScreenPreview({super.key});

  @override
  Widget build(BuildContext context) {
    // Wiring ala composition root — pakai fake repository untuk preview.
    final authRepository = FakeAuthRepository();
    final vaultRepository = FakeVaultRepository();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            initializeAuth: InitializeAuth(authRepository),
            createMasterPassword: CreateMasterPassword(authRepository),
            verifyMasterPassword: VerifyMasterPassword(authRepository),
            loginWithBiometrics: LoginWithBiometrics(authRepository),
            toggleBiometric: ToggleBiometric(authRepository),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => VaultProvider(
            loadVault: LoadVault(vaultRepository),
            addEntry: AddEntry(vaultRepository),
            updateEntry: UpdateEntry(vaultRepository),
            deleteEntry: DeleteEntry(vaultRepository),
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        // Sama dengan theme di lib/app.dart agar preview mirip app asli.
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const EntryScreen(),
      ),
    );
  }
}
