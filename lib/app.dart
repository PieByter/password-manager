import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import 'core/services/clipboard_service.dart';
import 'data/datasources/secure_storage_service.dart';
import 'data/encryption/encryption_service.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/settings_repository_impl.dart';
import 'data/repositories/vault_repository_impl.dart';
import 'domain/usecases/auth/change_master_password.dart';
import 'domain/usecases/auth/create_master_password.dart';
import 'domain/usecases/auth/initialize_auth.dart';
import 'domain/usecases/auth/lock_session.dart';
import 'domain/usecases/auth/login_with_biometrics.dart';
import 'domain/usecases/auth/toggle_biometric.dart';
import 'domain/usecases/auth/verify_master_password.dart';
import 'domain/usecases/vault/add_entry.dart';
import 'domain/usecases/vault/delete_entry.dart';
import 'domain/usecases/vault/load_vault.dart';
import 'domain/usecases/vault/update_entry.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/session/providers/session_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/vault/providers/vault_provider.dart';
import 'features/vault/screens/vault_screen.dart';

/// Composition root — satu-satunya tempat yang menghubungkan semua lapisan:
///
///   data (SecureStorageService, EncryptionService, SettingsRepositoryImpl)
///     → repositories (AuthRepositoryImpl, VaultRepositoryImpl)
///       → use cases (domain)
///         → providers (presentation)
///
/// Lapisan lain tidak pernah membuat dependency sendiri; semuanya
/// di-inject dari sini (Dependency Injection).
class PasswordManagerApp extends StatefulWidget {
  const PasswordManagerApp({super.key});

  @override
  State<PasswordManagerApp> createState() => _PasswordManagerAppState();
}

class _PasswordManagerAppState extends State<PasswordManagerApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final SettingsProvider _settingsProvider;
  late final AuthProvider _authProvider;
  late final VaultProvider _vaultProvider;
  late final SessionProvider _sessionProvider;
  late final ClipboardService _clipboardService;

  @override
  void initState() {
    super.initState();

    // 1) Data layer — framework details.
    final storage = SecureStorageService();
    final encryption = EncryptionService();
    final settingsRepository = SettingsRepositoryImpl();

    // 2) Repository implementations — dipakai lewat interface domain.
    final authRepository = AuthRepositoryImpl(
      storage: storage,
      encryption: encryption,
      localAuth: LocalAuthentication(),
    );
    final vaultRepository = VaultRepositoryImpl(
      storage: storage,
      encryption: encryption,
    );

    // 3) Use cases — business logic (domain).
    final initializeAuth = InitializeAuth(authRepository);
    final createMasterPassword = CreateMasterPassword(authRepository);
    final verifyMasterPassword = VerifyMasterPassword(authRepository);
    final loginWithBiometrics = LoginWithBiometrics(authRepository);
    final toggleBiometric = ToggleBiometric(authRepository);
    final lockSession = LockSession(authRepository);
    final changeMasterPassword = ChangeMasterPassword(
      authRepository: authRepository,
      vaultRepository: vaultRepository,
    );
    final loadVault = LoadVault(vaultRepository);
    final addEntry = AddEntry(vaultRepository);
    final updateEntry = UpdateEntry(vaultRepository);
    final deleteEntry = DeleteEntry(vaultRepository);

    // 4) Presentation state.
    _settingsProvider = SettingsProvider(repository: settingsRepository);
    _authProvider = AuthProvider(
      initializeAuth: initializeAuth,
      createMasterPassword: createMasterPassword,
      verifyMasterPassword: verifyMasterPassword,
      loginWithBiometrics: loginWithBiometrics,
      toggleBiometric: toggleBiometric,
      changeMasterPassword: changeMasterPassword,
      lockSession: lockSession,
    );
    _vaultProvider = VaultProvider(
      loadVault: loadVault,
      addEntry: addEntry,
      updateEntry: updateEntry,
      deleteEntry: deleteEntry,
    );
    _clipboardService = ClipboardService(
      clearSeconds: () => _settingsProvider.clipboardClearSeconds,
    );
    _sessionProvider = SessionProvider(
      auth: _authProvider,
      vault: _vaultProvider,
      settings: _settingsProvider,
      navigatorKey: _navigatorKey,
    );

    _settingsProvider.initialize();
    _authProvider.initialize();
  }

  @override
  void dispose() {
    _sessionProvider.dispose();
    _clipboardService.dispose();
    _authProvider.dispose();
    _vaultProvider.dispose();
    _settingsProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<VaultProvider>.value(value: _vaultProvider),
        ChangeNotifierProvider<SettingsProvider>.value(
          value: _settingsProvider,
        ),
        ChangeNotifierProvider<SessionProvider>.value(value: _sessionProvider),
        Provider<ClipboardService>.value(value: _clipboardService),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Password Manager',
            debugShowCheckedModeBanner: false,
            navigatorKey: _navigatorKey,
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
            themeMode: settings.themeMode,
            builder: (context, child) {
              return Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) =>
                    context.read<SessionProvider>().recordActivity(),
                onPointerSignal: (_) =>
                    context.read<SessionProvider>().recordActivity(),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const _AppEntry(),
          );
        },
      ),
    );
  }
}

/// Root widget — decides whether to show auth or vault screen.
class _AppEntry extends StatelessWidget {
  const _AppEntry();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final vault = context.watch<VaultProvider>();

    // Show loading while initializing.
    if (auth.status == AuthStatus.uninitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Show auth screen if not authenticated.
    if (!auth.isAuthenticated) {
      return const AuthScreen();
    }

    // Load once per unlocked session. `hasLoaded` prevents a reload loop for
    // an empty vault (and after the last entry is deleted).
    if (!vault.hasLoaded && !vault.isLoading && auth.masterPassword != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final password = context.read<AuthProvider>().masterPassword;
        if (password == null) return;
        context.read<VaultProvider>().loadVault(password);
      });
    }

    return const VaultScreen();
  }
}
