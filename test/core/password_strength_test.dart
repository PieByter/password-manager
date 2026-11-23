import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/core/security/password_strength.dart';

void main() {
  test('empty password is very weak', () {
    final strength = PasswordStrength.estimate('');

    expect(strength.score, 0);
    expect(strength.fraction, greaterThan(0));
  });

  test('common short password is weak', () {
    final strength = PasswordStrength.estimate('password');

    expect(strength.score, lessThanOrEqualTo(1));
  });

  test('long mixed password is strong', () {
    final strength = PasswordStrength.estimate('T7!vQ2#zL9@wR4\$kP8&m');

    expect(strength.score, greaterThanOrEqualTo(3));
  });

  test('repeated characters reduce the score', () {
    final repeated = PasswordStrength.estimate('aaaaaaaaaaaaaaaaaaaa');
    final distinct = PasswordStrength.estimate('aB3\$xY7!qW2@zR9#');

    expect(repeated.score, lessThan(distinct.score));
  });

  test('fraction stays within 0..1', () {
    for (final password in ['', 'abc', 'aB3\$xY7!qW2@zR9#']) {
      final strength = PasswordStrength.estimate(password);
      expect(strength.fraction, inInclusiveRange(0, 1));
    }
  });
}
