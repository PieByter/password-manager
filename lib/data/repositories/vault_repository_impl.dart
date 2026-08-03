// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import '../../domain/entities/password_entry.dart';
import '../../domain/repositories/vault_repository.dart';
import '../datasources/secure_storage_service.dart';
import '../encryption/encryption_service.dart';
import '../models/password_entry_model.dart';

/// Concrete implementation of [VaultRepository] (data layer).
///
/// Responsibilities hidden from the domain:
/// - reading/writing the encrypted JSON blob via [SecureStorageService]
/// - encrypting/decrypting with [EncryptionService]
/// - mapping between [PasswordEntryModel] (JSON) and [PasswordEntry] (domain)
/// - keeping entries sorted by most recently updated
class VaultRepositoryImpl implements VaultRepository {
  final SecureStorageService _storage;
  final EncryptionService _encryption;

  VaultRepositoryImpl({
    required SecureStorageService storage,
    required EncryptionService encryption,
  }) : _storage = storage,
       _encryption = encryption;

  @override
  Future<List<PasswordEntry>> loadVault(String masterPassword) async {
    final encrypted = await _storage.loadVault();
    if (encrypted == null || encrypted.isEmpty) return [];

    final salt = await _storage.getMasterPasswordSalt();
    if (salt == null) {
      throw StateError('Master password salt not found');
    }

    final jsonString = _encryption.decrypt(encrypted, masterPassword, salt);
    final jsonList = jsonDecode(jsonString) as List<dynamic>;
    final entries = jsonList
        .map((e) => PasswordEntryModel.fromJson(e as Map<String, dynamic>))
        .map((model) => model.toEntity())
        .toList();

    // Canonical order: most recently updated first.
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  @override
  Future<void> saveVault(
    List<PasswordEntry> entries,
    String masterPassword,
  ) async {
    final salt = await _storage.getMasterPasswordSalt();
    if (salt == null) {
      throw StateError('Master password salt not found');
    }

    final jsonString = jsonEncode(
      entries
          .map(PasswordEntryModel.fromEntity)
          .map((model) => model.toJson())
          .toList(),
    );
    final encrypted = _encryption.encrypt(jsonString, masterPassword, salt);
    await _storage.saveVault(encrypted);
  }
}
