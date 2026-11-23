import 'dart:math' as math;

/// Lightweight, dependency-free password strength estimator.
///
/// The estimate is entropy-based (pool size × length) with simple penalties
/// for repetition and sequential patterns. It is intentionally conservative
/// and is only used to guide the user, not as a security guarantee.
class PasswordStrength {
  /// 0 = very weak … 4 = very strong.
  final int score;
  final String label;
  final double entropyBits;

  const PasswordStrength({
    required this.score,
    required this.label,
    required this.entropyBits,
  });

  double get fraction => (score + 1) / 5;

  static PasswordStrength estimate(String password) {
    if (password.isEmpty) {
      return const PasswordStrength(
        score: 0,
        label: 'Very weak',
        entropyBits: 0,
      );
    }

    var poolSize = 0;
    if (password.contains(RegExp(r'[a-z]'))) poolSize += 26;
    if (password.contains(RegExp(r'[A-Z]'))) poolSize += 26;
    if (password.contains(RegExp(r'[0-9]'))) poolSize += 10;
    if (password.contains(RegExp(r'[^A-Za-z0-9]'))) poolSize += 33;
    if (poolSize == 0) poolSize = 1;

    var entropy = password.length * (math.log(poolSize) / math.ln2);

    // Penalise repeats and simple sequences.
    if (RegExp(r'(.)\1\1').hasMatch(password)) entropy *= 0.8;
    if (_hasSequence(password)) entropy *= 0.85;
    if (password.length < 8) {
      entropy = math.min(entropy, 24);
    }

    var score = switch (entropy) {
      < 28 => 0,
      < 40 => 1,
      < 60 => 2,
      < 80 => 3,
      _ => 4,
    };

    // Entropy alone overrates passwords with very little character variety
    // (e.g. "aaaaaaaaaaaaaaaaaaaa").
    final uniqueCharacters = password.split('').toSet().length;
    final diversityCap = switch (uniqueCharacters) {
      <= 4 => 1,
      <= 7 => 2,
      <= 10 => 3,
      _ => 4,
    };
    if (score > diversityCap) score = diversityCap;

    const labels = ['Very weak', 'Weak', 'Fair', 'Strong', 'Very strong'];
    return PasswordStrength(
      score: score,
      label: labels[score],
      entropyBits: entropy,
    );
  }

  static bool _hasSequence(String value) {
    const sequences = ['abcdefghijklmnopqrstuvwxyz', '0123456789'];
    final lower = value.toLowerCase();
    for (final sequence in sequences) {
      for (var i = 0; i + 4 <= sequence.length; i++) {
        final chunk = sequence.substring(i, i + 3);
        if (lower.contains(chunk) || lower.contains(_reverse(chunk))) {
          return true;
        }
      }
    }
    return false;
  }

  static String _reverse(String value) => value.split('').reversed.join();
}
