/// Pure domain entity.
///
/// Clean Architecture rule: the domain layer is independent of Flutter and
/// any framework. This class contains ONLY business data — no JSON
/// serialization. Serialization lives in `data/models/password_entry_model.dart`.
class PasswordEntry {
  final String id;
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;
  final String? totpSecret; // Base32 TOTP secret key
  final DateTime createdAt;
  final DateTime updatedAt;

  PasswordEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    this.url = '',
    this.notes = '',
    this.totpSecret,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  bool get hasTotp => totpSecret != null && totpSecret!.isNotEmpty;

  PasswordEntry copyWith({
    String? id,
    String? title,
    String? username,
    String? password,
    String? url,
    String? notes,
    String? totpSecret,
    bool clearTotp = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PasswordEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      totpSecret: clearTotp ? null : (totpSecret ?? this.totpSecret),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'PasswordEntry(title: $title, username: $username)';
}
