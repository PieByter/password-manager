import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;

/// Key material derived once per (password, salt) pair and cached for the
/// lifetime of the unlocked session.
///
/// The vault format is `v2:<ivBase64>:<cipherBase64>:<macBase64>` using
/// AES-256-CBC + HMAC-SHA256 (encrypt-then-MAC). The salt itself is stored
/// in secure storage, not inside the blob, because it is shared with the
/// master-password verifier.
class _DerivedKeys {
  final Uint8List encryptionKey;
  final Uint8List macKey;

  const _DerivedKeys({required this.encryptionKey, required this.macKey});
}

/// Cryptographic helper used by the data layer to protect data at rest.
///
/// Security properties:
/// - PBKDF2-HMAC-SHA256 with 100.000 iterations.
/// - Encryption key and authentication key are derived separately
///   (`enc|salt` vs `auth|salt`) so a leaked verifier is not a vault key.
/// - AES-256-CBC with a fresh random IV for every encryption.
/// - HMAC-SHA256 over the format version, IV and ciphertext, verified with a
///   constant-time comparison before decryption.
class EncryptionService {
  static const int _iterations = 100000;
  static const int _keyLength = 32;
  static const int _macLength = 32;
  static const int _saltLength = 32;
  static const String _formatVersion = 'v2';

  final Map<String, _DerivedKeys> _keyCache = {};

  /// Implements PBKDF2-HMAC-SHA256 (RFC 8018).
  Uint8List _pbkdf2(
    String password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final passwordBytes = utf8.encode(password);
    final hLen = sha256.convert(const []).bytes.length; // 32 bytes
    final blockCount = (keyLength + hLen - 1) ~/ hLen;
    final derived = Uint8List(keyLength);
    var offset = 0;

    for (var blockIndex = 1; blockIndex <= blockCount; blockIndex++) {
      final block = Uint8List(salt.length + 4)..setRange(0, salt.length, salt);
      block[salt.length] = (blockIndex >> 24) & 0xff;
      block[salt.length + 1] = (blockIndex >> 16) & 0xff;
      block[salt.length + 2] = (blockIndex >> 8) & 0xff;
      block[salt.length + 3] = blockIndex & 0xff;

      var u = Hmac(sha256, passwordBytes).convert(block).bytes;
      final t = Uint8List.fromList(u);

      for (var i = 2; i <= iterations; i++) {
        u = Hmac(sha256, passwordBytes).convert(u).bytes;
        for (var j = 0; j < hLen; j++) {
          t[j] ^= u[j];
        }
      }

      final copyLength = min(hLen, keyLength - offset);
      derived.setRange(offset, offset + copyLength, t.sublist(0, copyLength));
      offset += copyLength;
    }

    return derived;
  }

  /// Cache identity deliberately includes a hash of the password, so a key
  /// derived for an old password can never be reused after a password change
  /// even though the salt stays the same.
  String _cacheKey(String password, String salt) {
    return sha256.convert(utf8.encode('$salt\u0000$password')).toString();
  }

  _DerivedKeys _deriveKeys(String masterPassword, String salt) {
    final cacheKey = _cacheKey(masterPassword, salt);
    final cached = _keyCache[cacheKey];
    if (cached != null) return cached;

    final material = _pbkdf2(
      masterPassword,
      utf8.encode('enc|$salt'),
      _iterations,
      _keyLength + _macLength,
    );

    final keys = _DerivedKeys(
      encryptionKey: Uint8List.fromList(material.sublist(0, _keyLength)),
      macKey: Uint8List.fromList(material.sublist(_keyLength)),
    );
    _keyCache[cacheKey] = keys;
    return keys;
  }

  /// Generates a random salt string (32 secure-random bytes, Base64 encoded).
  String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    return base64.encode(bytes);
  }

  /// Derives the verifier stored in secure storage.
  ///
  /// Uses a separate domain (`auth|salt`) from the encryption key so the
  /// stored verifier cannot be used to decrypt the vault.
  String hashMasterPassword(String masterPassword, String salt) {
    final hash = _pbkdf2(
      masterPassword,
      utf8.encode('auth|$salt'),
      _iterations,
      _keyLength,
    );
    return base64.encode(hash);
  }

  /// Constant-time verification of the stored master-password verifier.
  bool verifyMasterPassword(String password, String salt, String expectedHash) {
    late final Uint8List expected;
    try {
      expected = base64.decode(expectedHash);
    } on FormatException {
      return false;
    }

    final actual = _pbkdf2(
      password,
      utf8.encode('auth|$salt'),
      _iterations,
      _keyLength,
    );
    return _constantTimeEquals(actual, expected);
  }

  /// Encrypts plaintext using AES-256-CBC + HMAC-SHA256 (encrypt-then-MAC).
  String encrypt(String plaintext, String masterPassword, String salt) {
    final keys = _deriveKeys(masterPassword, salt);
    final iv = encrypt_lib.IV.fromSecureRandom(16);
    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(
        encrypt_lib.Key(keys.encryptionKey),
        mode: encrypt_lib.AESMode.cbc,
      ),
    );
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    final mac = _computeMac(keys.macKey, iv.bytes, encrypted.bytes);
    return '$_formatVersion:${iv.base64}:${encrypted.base64}:${base64.encode(mac)}';
  }

  /// Decrypts a `v2` ciphertext after verifying its HMAC.
  ///
  /// Throws [FormatException] when the payload is malformed, tampered with, or
  /// the master password is wrong. Details are intentionally not exposed.
  String decrypt(String ciphertext, String masterPassword, String salt) {
    final parts = ciphertext.split(':');
    if (parts.length != 4 || parts[0] != _formatVersion) {
      throw const FormatException('Unsupported vault format');
    }

    late final encrypt_lib.IV iv;
    late final encrypt_lib.Encrypted encrypted;
    late final Uint8List mac;
    try {
      iv = encrypt_lib.IV.fromBase64(parts[1]);
      encrypted = encrypt_lib.Encrypted.fromBase64(parts[2]);
      mac = base64.decode(parts[3]);
    } on FormatException {
      throw const FormatException('Invalid vault payload');
    }

    final keys = _deriveKeys(masterPassword, salt);
    final expectedMac = _computeMac(keys.macKey, iv.bytes, encrypted.bytes);
    if (!_constantTimeEquals(mac, expectedMac)) {
      throw const FormatException('Vault integrity check failed');
    }

    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(
        encrypt_lib.Key(keys.encryptionKey),
        mode: encrypt_lib.AESMode.cbc,
      ),
    );
    return encrypter.decrypt(encrypted, iv: iv);
  }

  Uint8List _computeMac(Uint8List macKey, List<int> iv, List<int> ciphertext) {
    final payload = Uint8List.fromList([
      ...utf8.encode(_formatVersion),
      ...iv,
      ...ciphertext,
    ]);
    return Uint8List.fromList(Hmac(sha256, macKey).convert(payload).bytes);
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  /// Removes all derived key material from memory. Call when the vault locks.
  void clearKeyCache() {
    _keyCache.clear();
  }
}
