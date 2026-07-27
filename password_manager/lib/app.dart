import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/storage/secure_storage_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/vault/providers/vault_provider.dart';
import 'features/vault/screens/vault_screen.dart';

class PasswordManagerApp extends StatelessWidget {
  const PasswordManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = SecureStorageService();

    return MultiProvider(
      providers: [
        Provider<SecureStorageService>.value(value: storage),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(storage: storage),
        ),
        ChangeNotifierProvider<VaultProvider>(
          create: (_) => VaultProvider(storage: storage),
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
        vault.loadVault(auth.masterPassword!, auth.salt!);
      });
    }

    return const VaultScreen();
  }
}
