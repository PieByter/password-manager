import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../vault/providers/vault_provider.dart';

/// Coordinates the unlocked session: idle auto-lock and background timeout.
///
/// It owns no secrets itself; when the session ends it asks [AuthProvider] to
/// clear the in-memory master password and [VaultProvider] to drop decrypted
/// entries, then closes any open routes.
class SessionProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AuthProvider auth;
  final VaultProvider vault;
  final SettingsProvider settings;
  final GlobalKey<NavigatorState> navigatorKey;

  Timer? _autoLockTimer;
  DateTime? _backgroundedAt;

  SessionProvider({
    required this.auth,
    required this.vault,
    required this.settings,
    required this.navigatorKey,
  }) {
    WidgetsBinding.instance.addObserver(this);
    auth.addListener(_handleAuthChanged);
    settings.addListener(_handleSettingsChanged);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    if (auth.status == AuthStatus.authenticated) {
      recordActivity();
    }
  }

  /// Keyboard activity counts as user activity too, so typing in the entry
  /// form does not lock the vault after the idle timeout.
  bool _handleKeyEvent(KeyEvent event) {
    recordActivity();
    return false;
  }

  /// Call on any user interaction (pointer down) to postpone auto-lock.
  void recordActivity() {
    _autoLockTimer?.cancel();
    _autoLockTimer = null;

    if (auth.status != AuthStatus.authenticated) return;

    final minutes = settings.autoLockMinutes;
    if (minutes <= 0) return;

    _autoLockTimer = Timer(Duration(minutes: minutes), lock);
  }

  /// Locks the vault: clears secrets, closes routes and returns to auth.
  void lock() {
    _autoLockTimer?.cancel();
    _autoLockTimer = null;

    final wasUnlocked =
        auth.status == AuthStatus.authenticated || vault.hasLoaded;
    if (!wasUnlocked) return;

    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    vault.reset();
    auth.logout();
  }

  void _handleAuthChanged() {
    if (auth.status != AuthStatus.authenticated) {
      _autoLockTimer?.cancel();
      _autoLockTimer = null;
    } else {
      recordActivity();
    }
    notifyListeners();
  }

  void _handleSettingsChanged() {
    if (auth.status == AuthStatus.authenticated) {
      recordActivity();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;

        final minutes = settings.autoLockMinutes;
        if (backgroundedAt != null &&
            minutes > 0 &&
            DateTime.now().difference(backgroundedAt) >=
                Duration(minutes: minutes)) {
          lock();
          return;
        }
        recordActivity();
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    auth.removeListener(_handleAuthChanged);
    settings.removeListener(_handleSettingsChanged);
    _autoLockTimer?.cancel();
    super.dispose();
  }
}
