// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/encryption/encryption_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../models/password_entry.dart';

class VaultProvider extends ChangeNotifier {
  final SecureStorageService _storage;
  final EncryptionService _encryption;

  List<PasswordEntry> _entries = [];
  bool _isLoading = false;
  String _searchQuery = '';

  VaultProvider({
    required SecureStorageService storage,
    EncryptionService? encryption,
  }) : _storage = storage,
       _encryption = encryption ?? EncryptionService();

  List<PasswordEntry> get entries {
    if (_searchQuery.isEmpty) return List.unmodifiable(_entries);
    final query = _searchQuery.toLowerCase();
    return _entries.where((e) {
      return e.title.toLowerCase().contains(query) ||
          e.username.toLowerCase().contains(query) ||
          e.url.toLowerCase().contains(query);
    }).toList();
  }

  List<PasswordEntry> get allEntries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  set searchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Load vault from secure storage and decrypt it
  Future<void> loadVault(String masterPassword, String salt) async {
    _isLoading = true;
    notifyListeners();

    try {
      final encrypted = await _storage.loadVault();
      if (encrypted == null || encrypted.isEmpty) {
        _entries = [];
        return;
      }

      final jsonString = _encryption.decrypt(encrypted, masterPassword, salt);
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      _entries =
          jsonList
              .map((e) => PasswordEntry.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('Error loading vault: $e');
      _entries = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save vault — encrypt all entries and store
  Future<void> _persistVault(String masterPassword, String salt) async {
    final jsonString = jsonEncode(_entries.map((e) => e.toJson()).toList());
    final encrypted = _encryption.encrypt(jsonString, masterPassword, salt);
    await _storage.saveVault(encrypted);
  }

  /// Add a new password entry
  Future<void> addEntry({
    required String title,
    required String username,
    required String password,
    String url = '',
    String notes = '',
    String? totpSecret,
    required String masterPassword,
    required String salt,
  }) async {
    final entry = PasswordEntry(
      id: generateId(),
      title: title,
      username: username,
      password: password,
      url: url,
      notes: notes,
      totpSecret: totpSecret,
    );

    _entries.insert(0, entry);
    await _persistVault(masterPassword, salt);
    notifyListeners();
  }

  /// Update an existing entry
  Future<void> updateEntry({
    required String id,
    required String title,
    required String username,
    required String password,
    String url = '',
    String notes = '',
    String? totpSecret,
    bool clearTotp = false,
    required String masterPassword,
    required String salt,
  }) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index == -1) return;

    _entries[index] = _entries[index].copyWith(
      title: title,
      username: username,
      password: password,
      url: url,
      notes: notes,
      totpSecret: totpSecret,
      clearTotp: clearTotp,
      updatedAt: DateTime.now(),
    );

    _entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persistVault(masterPassword, salt);
    notifyListeners();
  }

  /// Delete an entry
  Future<void> deleteEntry(
    String id,
    String masterPassword,
    String salt,
  ) async {
    _entries.removeWhere((e) => e.id == id);
    await _persistVault(masterPassword, salt);
    notifyListeners();
  }

  /// Get a single entry by ID
  PasswordEntry? getEntryById(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
