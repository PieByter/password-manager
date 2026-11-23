// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import '../../../domain/entities/password_entry.dart';
import '../../../domain/usecases/vault/add_entry.dart';
import '../../../domain/usecases/vault/delete_entry.dart';
import '../../../domain/usecases/vault/load_vault.dart';
import '../../../domain/usecases/vault/update_entry.dart';

/// Presentation-layer state manager for the vault.
///
/// Clean Architecture: business rules (ID generation, insert/update/delete,
/// persistence) live in the domain use cases. This class keeps a cached
/// list of entries for the UI, handles loading state and search filtering.
class VaultProvider extends ChangeNotifier {
  final LoadVault _loadVault;
  final AddEntry _addEntry;
  final UpdateEntry _updateEntry;
  final DeleteEntry _deleteEntry;

  List<PasswordEntry> _entries = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  String _searchQuery = '';

  VaultProvider({
    required LoadVault loadVault,
    required AddEntry addEntry,
    required UpdateEntry updateEntry,
    required DeleteEntry deleteEntry,
  }) : _loadVault = loadVault,
       _addEntry = addEntry,
       _updateEntry = updateEntry,
       _deleteEntry = deleteEntry;

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
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;

  set searchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Load vault via the use case — storage & decryption are hidden.
  ///
  /// [hasLoaded] (not `entries.isEmpty`) is the source of truth so an empty
  /// vault does not trigger an endless reload loop.
  Future<void> loadVault(String masterPassword, {bool force = false}) async {
    if (_isLoading || (_hasLoaded && !force)) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _entries = await _loadVault(masterPassword);
    } catch (e) {
      debugPrint('Error loading vault: $e');
      _entries = [];
      _errorMessage = 'Could not open the vault. The data may be corrupted.';
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  /// Drop all decrypted data when the session locks.
  void reset() {
    _entries = [];
    _searchQuery = '';
    _errorMessage = null;
    _isLoading = false;
    _hasLoaded = false;
    notifyListeners();
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
  }) async {
    _entries = await _addEntry(
      AddEntryParams(
        masterPassword: masterPassword,
        title: title,
        username: username,
        password: password,
        url: url,
        notes: notes,
        totpSecret: totpSecret,
      ),
    );
    _hasLoaded = true;
    _errorMessage = null;
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
  }) async {
    _entries = await _updateEntry(
      UpdateEntryParams(
        masterPassword: masterPassword,
        id: id,
        title: title,
        username: username,
        password: password,
        url: url,
        notes: notes,
        totpSecret: totpSecret,
        clearTotp: clearTotp,
      ),
    );
    _hasLoaded = true;
    _errorMessage = null;
    notifyListeners();
  }

  /// Delete an entry
  Future<void> deleteEntry(String id, String masterPassword) async {
    _entries = await _deleteEntry(id: id, masterPassword: masterPassword);
    _hasLoaded = true;
    _errorMessage = null;
    notifyListeners();
  }

  /// Get a single entry by ID from the cached list
  PasswordEntry? getEntryById(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
