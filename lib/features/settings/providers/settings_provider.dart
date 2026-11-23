// ignore_for_file: prefer_initializing_formals

import 'package:flutter/material.dart';

import '../../../domain/repositories/settings_repository.dart';

/// Presentation-layer state for user preferences.
class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _repository;

  ThemeMode _themeMode = ThemeMode.system;
  int _autoLockMinutes = 5;
  int _clipboardClearSeconds = 30;
  bool _initialized = false;

  SettingsProvider({required SettingsRepository repository})
    : _repository = repository;

  ThemeMode get themeMode => _themeMode;
  int get autoLockMinutes => _autoLockMinutes;
  int get clipboardClearSeconds => _clipboardClearSeconds;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    try {
      final theme = await _repository.readThemeMode();
      _themeMode = switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      final autoLock = await _repository.readAutoLockMinutes() ?? 5;
      _autoLockMinutes = const [0, 1, 5, 15].contains(autoLock) ? autoLock : 5;

      final clipboard = await _repository.readClipboardClearSeconds() ?? 30;
      _clipboardClearSeconds = const [0, 15, 30, 60].contains(clipboard)
          ? clipboard
          : 30;
    } catch (e) {
      debugPrint('Failed to load settings: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      await _repository.writeThemeMode(mode.name);
    } catch (e) {
      debugPrint('Failed to persist theme mode: $e');
    }
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    if (_autoLockMinutes == minutes) return;
    _autoLockMinutes = minutes;
    notifyListeners();
    try {
      await _repository.writeAutoLockMinutes(minutes);
    } catch (e) {
      debugPrint('Failed to persist auto-lock timeout: $e');
    }
  }

  Future<void> setClipboardClearSeconds(int seconds) async {
    if (_clipboardClearSeconds == seconds) return;
    _clipboardClearSeconds = seconds;
    notifyListeners();
    try {
      await _repository.writeClipboardClearSeconds(seconds);
    } catch (e) {
      debugPrint('Failed to persist clipboard timeout: $e');
    }
  }
}
