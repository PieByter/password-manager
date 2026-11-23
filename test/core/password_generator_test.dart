import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/core/security/password_generator.dart';

void main() {
  test('respects the requested length', () {
    for (final length in [12, 16, 20, 64]) {
      final password = PasswordGenerator.generate(
        options: PasswordOptions(length: length),
      );
      expect(password.length, length);
    }
  });

  test('contains every enabled character class', () {
    final password = PasswordGenerator.generate(
      options: const PasswordOptions(length: 24),
    );

    expect(password.contains(RegExp(r'[a-z]')), isTrue);
    expect(password.contains(RegExp(r'[A-Z]')), isTrue);
    expect(password.contains(RegExp(r'[0-9]')), isTrue);
    expect(password.contains(RegExp(r'[^A-Za-z0-9]')), isTrue);
  });

  test('only uses enabled classes', () {
    final password = PasswordGenerator.generate(
      options: const PasswordOptions(
        length: 32,
        useUppercase: false,
        useLowercase: true,
        useDigits: true,
        useSymbols: false,
      ),
    );

    expect(RegExp(r'^[a-z0-9]+$').hasMatch(password), isTrue);
  });

  test('avoids ambiguous characters when requested', () {
    final generated = List.generate(
      20,
      (_) => PasswordGenerator.generate(
        options: const PasswordOptions(length: 32, useSymbols: false),
      ),
    ).join();

    expect(RegExp(r'[Il1O0o]').hasMatch(generated), isFalse);
  });

  test('throws when no character class is enabled', () {
    expect(
      () => PasswordGenerator.generate(
        options: const PasswordOptions(
          useUppercase: false,
          useLowercase: false,
          useDigits: false,
          useSymbols: false,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('produces different passwords across calls', () {
    final passwords = List.generate(
      10,
      (_) => PasswordGenerator.generate(),
    ).toSet();

    expect(passwords.length, 10);
  });
}
