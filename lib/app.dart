import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'data/datasources/secure_storage_service.dart';
import 'data/encryption/encryption_service.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/vault_repository_impl.dart';
import 'domain/usecases/auth/create_master_password.dart';
import 'domain/usecases/auth/initialize_auth.dart';
import 'domain/usecases/auth/login_with_biometrics.dart';
import 'domain/usecases/auth/toggle_biometric.dart';
import 'domain/usecases/auth/verify_master_password.dart';
import 'domain/usecases/vault/add_entry.dart';
import 'domain/usecases/vault/delete_entry.dart';
import 'domain/usecases/vault/load_vault.dart';
import 'domain/usecases/vault/update_entry.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/vault/providers/vault_provider.dart';
import 'features/vault/screens/vault_screen.dart';

/// Composition root — satu-satunya tempat yang menghubungkan semua lapisan:
///
///   data (SecureStorageService, EncryptionService)
///     → repositories (AuthRepositoryImpl, VaultRepositoryImpl)
///       → use cases (domain)
///         → providers (presentation)
///
/// Lapisan lain tidak pernah membuat dependency sendiri; semuanya
/// di-inject dari sini (Dependency Injection).
class PasswordManagerApp extends StatelessWidget {
  const PasswordManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1) Data layer — framework details
    final storage = SecureStorageService();
    final encryption = EncryptionService();

    // 2) Repository implementations — dipakai lewat interface domain
    final authRepository = AuthRepositoryImpl(
      storage: storage,
      encryption: encryption,
      localAuth: LocalAuthentication(),
    );
    final vaultRepository = VaultRepositoryImpl(
      storage: storage,
      encryption: encryption,
    );

    // 3) Use cases — business logic (domain)
    final initializeAuth = InitializeAuth(authRepository);
    final createMasterPassword = CreateMasterPassword(authRepository);
    final verifyMasterPassword = VerifyMasterPassword(authRepository);
    final loginWithBiometrics = LoginWithBiometrics(authRepository);
    final toggleBiometric = ToggleBiometric(authRepository);
    final loadVault = LoadVault(vaultRepository);
    final addEntry = AddEntry(vaultRepository);
    final updateEntry = UpdateEntry(vaultRepository);
    final deleteEntry = DeleteEntry(vaultRepository);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            initializeAuth: initializeAuth,
            createMasterPassword: createMasterPassword,
            verifyMasterPassword: verifyMasterPassword,
            loginWithBiometrics: loginWithBiometrics,
            toggleBiometric: toggleBiometric,
          ),
        ),
        ChangeNotifierProvider<VaultProvider>(
          create: (_) => VaultProvider(
            loadVault: loadVault,
            addEntry: addEntry,
            updateEntry: updateEntry,
            deleteEntry: deleteEntry,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Password Manager',
        debugShowCheckedModeBanner: false,
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
        home: const _AppEntry(),
      ),
    );
  }
}

/// Root widget — decides whether to show auth or vault screen
class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  @override
  void initState() {
    super.initState();
    // Initialize auth provider on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final vault = context.watch<VaultProvider>();

    // Show loading while initializing
    if (auth.status == AuthStatus.uninitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Show auth screen if not authenticated
    if (auth.status != AuthStatus.authenticated) {
      return const AuthScreen();
    }

    // Load vault if not yet loaded
    if (vault.allEntries.isEmpty && !vault.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        vault.loadVault(auth.masterPassword!);
      });
    }

    return const VaultScreen();
  }
}
