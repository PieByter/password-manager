import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class TotpService {
  static const _base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Decodes a Base32-encoded string (RFC 4648)
  static Uint8List _base32Decode(String input) {
    // Normalize: uppercase, remove spaces and padding
    input = input.replaceAll(' ', '').toUpperCase().replaceAll('=', '');

    final output = <int>[];
    var buffer = 0;
    var bitsLeft = 0;

    for (var i = 0; i < input.length; i++) {
      final val = _base32Chars.indexOf(input[i]);
      if (val < 0) continue;

      buffer = (buffer << 5) | val;
      bitsLeft += 5;

      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        output.add((buffer >> bitsLeft) & 0xFF);
      }
    }

    return Uint8List.fromList(output);
  }

  /// Generates a random Base32 secret key for TOTP setup
  /// Returns a string like "JBSWY3DPEHPK3PXP"
  static String generateSecret({int length = 20}) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return _base32Encode(bytes);
  }

  /// Encodes bytes to Base32 string (RFC 4648)
  static String _base32Encode(List<int> bytes) {
    final output = StringBuffer();
    var buffer = 0;
    var bitsLeft = 0;

    for (var i = 0; i < bytes.length; i++) {
      buffer = (buffer << 8) | (bytes[i] & 0xFF);
      bitsLeft += 8;

      while (bitsLeft >= 5) {
        bitsLeft -= 5;
        output.write(_base32Chars[(buffer >> bitsLeft) & 0x1F]);
      }
    }

    if (bitsLeft > 0) {
      output.write(_base32Chars[(buffer << (5 - bitsLeft)) & 0x1F]);
    }

    return output.toString();
  }

  /// Generates a TOTP code for the given secret key
  /// Uses SHA-1 as digest (standard RFC 6238)
  /// Returns a 6-digit code as string, e.g. "123456"
  static String generateCode(String secret) {
    final key = _base32Decode(secret);
    final time = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
    final counter = time ~/ 30;

    // Create 8-byte big-endian counter
    final counterBytes = Uint8List(8);
    var c = counter;
    for (var i = 7; i >= 0; i--) {
      counterBytes[i] = c & 0xff;
      c >>= 8;
    }

    // HMAC-SHA1
    final hmac = Hmac(sha1, key);
    final hmacResult = hmac.convert(counterBytes).bytes;

    // Dynamic truncation (RFC 4226)
    final offset = hmacResult[19] & 0xf;
    final code =
        ((hmacResult[offset] & 0x7f) << 24) |
        ((hmacResult[offset + 1] & 0xff) << 16) |
        ((hmacResult[offset + 2] & 0xff) << 8) |
        (hmacResult[offset + 3] & 0xff);

    final otp = code % 1000000;
    return otp.toString().padLeft(6, '0');
  }

  /// Returns seconds remaining in the current 30-second window
  static int getRemainingSeconds() {
    return 30 - (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 30;
  }

  /// Validates whether a secret key is valid Base32 format
  static bool isValidSecret(String secret) {
    final cleaned = secret
        .replaceAll(' ', '')
        .toUpperCase()
        .replaceAll('=', '');
    if (cleaned.isEmpty) return false;
    return cleaned.split('').every((c) => _base32Chars.contains(c));
  }

  /// Generates an otpauth:// URI for QR code creation
  /// Format: otpauth://totp/{issuer}:{account}?secret={secret}&issuer={issuer}
  static String generateOtpauthUri({
    required String secret,
    required String account,
    String issuer = 'Password Manager',
  }) {
    final encodedIssuer = Uri.encodeComponent(issuer);
    final encodedAccount = Uri.encodeComponent(account);
    return 'otpauth://totp/$encodedIssuer:$encodedAccount'
        '?secret=$secret&issuer=$encodedIssuer';
  }
}
