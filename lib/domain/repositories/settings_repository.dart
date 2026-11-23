/// Repository interface for non-secret user preferences.
///
/// The domain defines the contract; `data` provides the secure-storage-backed
/// implementation. Presentation only depends on this abstraction.
abstract class SettingsRepository {
  Future<String?> readThemeMode();
  Future<void> writeThemeMode(String value);

  Future<int?> readAutoLockMinutes();
  Future<void> writeAutoLockMinutes(int value);

  Future<int?> readClipboardClearSeconds();
  Future<void> writeClipboardClearSeconds(int value);
}
