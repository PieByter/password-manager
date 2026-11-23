import 'package:flutter/material.dart';

import '../../../core/security/password_generator.dart';
import '../../../core/security/password_strength.dart';

/// Bottom sheet that lets the user tune and preview a generated password.
///
/// Pops with the chosen password, or `null` when cancelled.
class PasswordGeneratorSheet extends StatefulWidget {
  final PasswordOptions initialOptions;

  const PasswordGeneratorSheet({
    super.key,
    this.initialOptions = const PasswordOptions(),
  });

  static Future<String?> show(
    BuildContext context, {
    PasswordOptions initialOptions = const PasswordOptions(),
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PasswordGeneratorSheet(initialOptions: initialOptions),
    );
  }

  @override
  State<PasswordGeneratorSheet> createState() => _PasswordGeneratorSheetState();
}

class _PasswordGeneratorSheetState extends State<PasswordGeneratorSheet> {
  late PasswordOptions _options;
  late String _password;
  late PasswordStrength _strength;

  @override
  void initState() {
    super.initState();
    _options = widget.initialOptions;
    _regenerate();
  }

  void _regenerate() {
    _password = PasswordGenerator.generate(options: _options);
    _strength = PasswordStrength.estimate(_password);
  }

  void _updateOptions(PasswordOptions options) {
    final hasCharacterClass =
        options.useUppercase ||
        options.useLowercase ||
        options.useDigits ||
        options.useSymbols;
    if (!hasCharacterClass) return;

    setState(() {
      _options = options;
      _regenerate();
    });
  }

  Color _strengthColor(int score) {
    return switch (score) {
      0 => Colors.red,
      1 => Colors.orange,
      2 => Colors.amber,
      3 => Colors.lightGreen,
      _ => Colors.green,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Generate Password',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Regenerate',
                  onPressed: () => setState(_regenerate),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                _password,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _strength.fraction,
                      minHeight: 6,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        _strengthColor(_strength.score),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(_strength.label, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Length', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(
                  '${_options.length}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: _options.length.toDouble(),
              min: 12,
              max: 64,
              divisions: 52,
              label: '${_options.length}',
              onChanged: (value) =>
                  _updateOptions(_options.copyWith(length: value.round())),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilterChip(
                  label: const Text('A-Z'),
                  selected: _options.useUppercase,
                  onSelected: (selected) =>
                      _updateOptions(_options.copyWith(useUppercase: selected)),
                ),
                FilterChip(
                  label: const Text('a-z'),
                  selected: _options.useLowercase,
                  onSelected: (selected) =>
                      _updateOptions(_options.copyWith(useLowercase: selected)),
                ),
                FilterChip(
                  label: const Text('0-9'),
                  selected: _options.useDigits,
                  onSelected: (selected) =>
                      _updateOptions(_options.copyWith(useDigits: selected)),
                ),
                FilterChip(
                  label: const Text('!@#'),
                  selected: _options.useSymbols,
                  onSelected: (selected) =>
                      _updateOptions(_options.copyWith(useSymbols: selected)),
                ),
                FilterChip(
                  avatar: const Icon(Icons.visibility_off, size: 16),
                  label: const Text('No ambiguous'),
                  selected: _options.avoidAmbiguous,
                  onSelected: (selected) => _updateOptions(
                    _options.copyWith(avoidAmbiguous: selected),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(_password),
                    icon: const Icon(Icons.check),
                    label: const Text('Use Password'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
