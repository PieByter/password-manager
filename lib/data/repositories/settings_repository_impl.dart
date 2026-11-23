import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/repositories/settings_repository.dart';

/// Secure-storage implementation of [SettingsRepository].
///
/// Preferences are small and not security-sensitive; storing them alongside
/// the vault avoids adding another plugin. Vault secrets remain in
/// `SecureStorageService`.
class SettingsRepositoryImpl implements SettingsRepository {
  final FlutterSecureStorage _storage;

  SettingsRepositoryImpl({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _keyThemeMode = 'settings_theme_mode';
  static const _keyAutoLockMinutes = 'settings_auto_lock_minutes';
  static const _keyClipboardClearSeconds = 'settings_clipboard_clear_seconds';

  @override
  Future<String?> readThemeMode() => _storage.read(key: _keyThemeMode);

  @override
  Future<void> writeThemeMode(String value) =>
      _storage.write(key: _keyThemeMode, value: value);

  @override
  Future<int?> readAutoLockMinutes() async {
    final value = await _storage.read(key: _keyAutoLockMinutes);
    return int.tryParse(value ?? '');
  }

  @override
  Future<void> writeAutoLockMinutes(int value) =>
      _storage.write(key: _keyAutoLockMinutes, value: value.toString());

  @override
  Future<int?> readClipboardClearSeconds() async {
    final value = await _storage.read(key: _keyClipboardClearSeconds);
    return int.tryParse(value ?? '');
  }

  @override
  Future<void> writeClipboardClearSeconds(int value) =>
      _storage.write(key: _keyClipboardClearSeconds, value: value.toString());
}
