import '../../domain/entities/password_entry.dart';

/// Data-layer model.
///
/// Extends the pure domain entity and adds JSON (de)serialization, which
/// belongs to the data layer — NOT the domain. The repository maps between
/// this model and the entity.
class PasswordEntryModel extends PasswordEntry {
  PasswordEntryModel({
    required super.id,
    required super.title,
    required super.username,
    required super.password,
    super.url,
    super.notes,
    super.totpSecret,
    super.createdAt,
    super.updatedAt,
  });

  factory PasswordEntryModel.fromEntity(PasswordEntry entry) {
    return PasswordEntryModel(
      id: entry.id,
      title: entry.title,
      username: entry.username,
      password: entry.password,
      url: entry.url,
      notes: entry.notes,
      totpSecret: entry.totpSecret,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  factory PasswordEntryModel.fromJson(Map<String, dynamic> json) {
    return PasswordEntryModel(
      id: json['id'] as String,
      title: json['title'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      url: json['url'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      totpSecret: json['totpSecret'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'username': username,
      'password': password,
      'url': url,
      'notes': notes,
      'totpSecret': totpSecret,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// A model IS-A entity, but we map explicitly to keep the entity layer pure.
  PasswordEntry toEntity() {
    return PasswordEntry(
      id: id,
      title: title,
      username: username,
      password: password,
      url: url,
      notes: notes,
      totpSecret: totpSecret,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
