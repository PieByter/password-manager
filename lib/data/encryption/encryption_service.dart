import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;

/// Cryptographic helper used by the data layer to protect data at rest.
/// Lives in the DATA layer because it is an implementation detail
/// (AES-256-CBC + PBKDF2) of how the vault is persisted.
class EncryptionService {
  /// Implements PBKDF2-HMAC-SHA256 key derivation
  /// Returns a 32-byte (256-bit) derived key.
  Uint8List _pbkdf2(
    String password,
    String salt,
    int iterations,
    int keyLength,
  ) {
    final passwordBytes = utf8.encode(password);
    final saltBytes = utf8.encode(salt);
    final hLen = sha256.convert([]).bytes.length; // 32 bytes
    final l = (keyLength + hLen - 1) ~/ hLen;
    final dk = Uint8List(keyLength);
    var pos = 0;

    for (var i = 1; i <= l; i++) {
      // Create block: salt || INT_32_BE(i)
      final block = Uint8List(saltBytes.length + 4);
      block.setRange(0, saltBytes.length, saltBytes);
      block[saltBytes.length] = (i >> 24) & 0xff;
      block[saltBytes.length + 1] = (i >> 16) & 0xff;
      block[saltBytes.length + 2] = (i >> 8) & 0xff;
      block[saltBytes.length + 3] = i & 0xff;

      // U1 = HMAC-SHA256(password, salt || INT_32_BE(i))
      var u = Hmac(sha256, passwordBytes).convert(block).bytes;

      // T = U1
      var t = Uint8List.fromList(u);

      // U2..Uc
      for (var j = 2; j <= iterations; j++) {
        u = Hmac(sha256, passwordBytes).convert(u).bytes;
        for (var k = 0; k < hLen; k++) {
          t[k] ^= u[k];
        }
      }

      // Append T to derived key
      final copyLen = min(hLen, dk.length - pos);
      dk.setRange(pos, pos + copyLen, t.sublist(0, copyLen));
      pos += copyLen;
    }

    return dk;
  }

  // Derives a 32-byte AES key from the master password using PBKDF2
  encrypt_lib.Key _deriveKey(String masterPassword, String salt) {
    final keyBytes = _pbkdf2(masterPassword, salt, 100000, 32);
    return encrypt_lib.Key.fromUtf8(base64.encode(keyBytes));
  }

  /// Generates a random salt string
  String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64.encode(bytes);
  }

  /// Hashes the master password with the salt for storage/verification
  String hashMasterPassword(String masterPassword, String salt) {
    final hash = _pbkdf2(masterPassword, salt, 100000, 32);
    return base64.encode(hash);
  }

  /// Encrypts plaintext using AES-256-CBC with a random IV
  String encrypt(String plaintext, String masterPassword, String salt) {
    final key = _deriveKey(masterPassword, salt);
    final iv = encrypt_lib.IV.fromSecureRandom(16);
    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc),
    );
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    final ivBase64 = iv.base64;
    final cipherBase64 = encrypted.base64;
    return '$ivBase64:$cipherBase64';
  }

  /// Decrypts ciphertext that was encrypted with [encrypt]
  String decrypt(String ciphertext, String masterPassword, String salt) {
    final key = _deriveKey(masterPassword, salt);
    final parts = ciphertext.split(':');
    if (parts.length != 2) {
      throw ArgumentError('Invalid ciphertext format');
    }
    final iv = encrypt_lib.IV.fromBase64(parts[0]);
    final encrypted = encrypt_lib.Encrypted.fromBase64(parts[1]);
    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc),
    );
    return encrypter.decrypt(encrypted, iv: iv);
  }
}
