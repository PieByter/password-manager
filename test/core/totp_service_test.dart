import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/core/totp/totp_service.dart';

void main() {
  // Base32 of the RFC 6238 SHA-1 seed "12345678901234567890".
  const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

  String codeAt(int unixSeconds) {
    final at = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    );
    return TotpService.generateCode(secret, at: at);
  }

  test('matches RFC 6238 SHA-1 vectors (last six digits)', () {
    expect(codeAt(59), '287082');
    expect(codeAt(1111111109), '081804');
    expect(codeAt(1111111111), '050471');
    expect(codeAt(1234567890), '005924');
    expect(codeAt(2000000000), '279037');
    expect(codeAt(20000000000), '353130');
  });

  test('remaining seconds are within the 30-second window', () {
    final at = DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true);
    expect(TotpService.getRemainingSeconds(at: at), 1);
  });

  test('generated secrets are valid Base32 and unique', () {
    final first = TotpService.generateSecret();
    final second = TotpService.generateSecret();

    expect(TotpService.isValidSecret(first), isTrue);
    expect(TotpService.isValidSecret(second), isTrue);
    expect(first, isNot(equals(second)));
  });

  test('invalid secrets are rejected', () {
    expect(TotpService.isValidSecret(''), isFalse);
    expect(TotpService.isValidSecret('not-base32!'), isFalse);
  });
}
