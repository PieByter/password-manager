import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/data/encryption/encryption_service.dart';

void main() {
  late EncryptionService service;
  late String salt;
  const password = 'correct horse battery staple';

  setUp(() {
    service = EncryptionService();
    salt = service.generateSalt();
  });

  test('encrypt/decrypt round-trip', () {
    final ciphertext = service.encrypt('rahasia vault', password, salt);

    expect(ciphertext, startsWith('v2:'));
    expect(service.decrypt(ciphertext, password, salt), 'rahasia vault');
  });

  test('every encryption uses a fresh IV', () {
    final first = service.encrypt('same plaintext', password, salt);
    final second = service.encrypt('same plaintext', password, salt);

    expect(first, isNot(equals(second)));
  });

  test('wrong master password is rejected', () {
    final ciphertext = service.encrypt('secret', password, salt);

    expect(
      () => service.decrypt(ciphertext, 'wrong password', salt),
      throwsA(isA<FormatException>()),
    );
  });

  test('tampered ciphertext is rejected by the MAC', () {
    final ciphertext = service.encrypt('secret', password, salt);
    final parts = ciphertext.split(':');
    final bytes = base64.decode(parts[2]);
    bytes[0] ^= 0x01;
    final tampered =
        '${parts[0]}:${parts[1]}:${base64.encode(bytes)}:${parts[3]}';

    expect(
      () => service.decrypt(tampered, password, salt),
      throwsA(isA<FormatException>()),
    );
  });

  test('tampered MAC is rejected', () {
    final ciphertext = service.encrypt('secret', password, salt);
    final parts = ciphertext.split(':');
    final mac = base64.decode(parts[3]);
    mac[0] ^= 0x01;
    final tampered =
        '${parts[0]}:${parts[1]}:${parts[2]}:${base64.encode(mac)}';

    expect(
      () => service.decrypt(tampered, password, salt),
      throwsA(isA<FormatException>()),
    );
  });

  test('master password verifier accepts the right password only', () {
    final hash = service.hashMasterPassword(password, salt);

    expect(service.verifyMasterPassword(password, salt, hash), isTrue);
    expect(service.verifyMasterPassword('nope', salt, hash), isFalse);
    expect(service.verifyMasterPassword(password, 'other-salt', hash), isFalse);
    expect(
      service.verifyMasterPassword(password, salt, 'not-base64!'),
      isFalse,
    );
  });

  test('changing password with the same salt invalidates the old key', () {
    final ciphertext = service.encrypt('secret', password, salt);

    expect(
      () => service.decrypt(ciphertext, 'new password', salt),
      throwsA(isA<FormatException>()),
    );
    expect(service.decrypt(ciphertext, password, salt), 'secret');
  });

  test('clearKeyCache forces re-derivation and still decrypts', () {
    final ciphertext = service.encrypt('secret', password, salt);
    service.clearKeyCache();

    expect(service.decrypt(ciphertext, password, salt), 'secret');
  });
}
