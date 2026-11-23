import 'dart:math';

/// Options used when generating a password.
class PasswordOptions {
  final int length;
  final bool useUppercase;
  final bool useLowercase;
  final bool useDigits;
  final bool useSymbols;
  final bool avoidAmbiguous;

  const PasswordOptions({
    this.length = 20,
    this.useUppercase = true,
    this.useLowercase = true,
    this.useDigits = true,
    this.useSymbols = true,
    this.avoidAmbiguous = true,
  }) : assert(length >= 8 && length <= 128, 'Length must be 8..128');

  PasswordOptions copyWith({
    int? length,
    bool? useUppercase,
    bool? useLowercase,
    bool? useDigits,
    bool? useSymbols,
    bool? avoidAmbiguous,
  }) {
    return PasswordOptions(
      length: length ?? this.length,
      useUppercase: useUppercase ?? this.useUppercase,
      useLowercase: useLowercase ?? this.useLowercase,
      useDigits: useDigits ?? this.useDigits,
      useSymbols: useSymbols ?? this.useSymbols,
      avoidAmbiguous: avoidAmbiguous ?? this.avoidAmbiguous,
    );
  }
}

/// Cryptographically secure password generator.
///
/// All randomness comes from [Random.secure]. Every selected character class
/// is guaranteed to appear at least once, then the result is shuffled with
/// Fisher–Yates so the guaranteed characters are not predictably placed.
class PasswordGenerator {
  static const _lowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _digits = '0123456789';
  static const _symbols = r'!@#$%^&*()-_=+[]{};:,.<>?/';
  static const _ambiguous = 'Il1O0o';

  static String _clean(String characters, bool avoidAmbiguous) {
    if (!avoidAmbiguous) return characters;
    return characters.split('').where((c) => !_ambiguous.contains(c)).join();
  }

  /// Generates a password according to [options].
  ///
  /// Throws [ArgumentError] if every character class is disabled.
  static String generate({PasswordOptions options = const PasswordOptions()}) {
    final sets = <String>[
      if (options.useLowercase) _clean(_lowercase, options.avoidAmbiguous),
      if (options.useUppercase) _clean(_uppercase, options.avoidAmbiguous),
      if (options.useDigits) _clean(_digits, options.avoidAmbiguous),
      if (options.useSymbols) _clean(_symbols, options.avoidAmbiguous),
    ].where((set) => set.isNotEmpty).toList();

    if (sets.isEmpty) {
      throw ArgumentError('At least one character class must be enabled');
    }

    final random = Random.secure();
    final chars = <String>[];

    // Guarantee one character from every enabled class.
    for (final set in sets) {
      chars.add(set[random.nextInt(set.length)]);
    }

    final pool = sets.join();
    while (chars.length < options.length) {
      chars.add(pool[random.nextInt(pool.length)]);
    }

    // Fisher–Yates with a secure RNG.
    for (var i = chars.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final tmp = chars[i];
      chars[i] = chars[j];
      chars[j] = tmp;
    }

    return chars.join();
  }
}
