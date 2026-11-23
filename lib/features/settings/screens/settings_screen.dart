import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../session/providers/session_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _toggleBiometric(BuildContext context, bool value) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isBiometricAvailable) {
      _showMessage(context, 'Biometrics are not available on this device');
      return;
    }

    final success = await auth.toggleBiometric(value);
    if (!context.mounted) return;
    if (!success) {
      _showMessage(
        context,
        'Could not ${value ? 'enable' : 'disable'} biometric unlock',
      );
    }
  }

  Future<void> _changeMasterPassword(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ChangeMasterPasswordDialog(),
    );

    if (changed == true && context.mounted) {
      _showMessage(context, 'Master password changed');
    }
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final session = context.read<SessionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Theme'),
            subtitle: const Text('System, light or dark'),
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<ThemeMode>(
                value: settings.themeMode,
                onChanged: (mode) {
                  if (mode != null) settings.setThemeMode(mode);
                },
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                ],
              ),
            ),
          ),
          const Divider(),
          const _SectionHeader('Security'),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Auto-lock'),
            subtitle: const Text('Lock after a period of inactivity'),
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: settings.autoLockMinutes,
                onChanged: (minutes) {
                  if (minutes != null) settings.setAutoLockMinutes(minutes);
                },
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 min')),
                  DropdownMenuItem(value: 5, child: Text('5 min')),
                  DropdownMenuItem(value: 15, child: Text('15 min')),
                  DropdownMenuItem(value: 0, child: Text('Never')),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.content_paste_off),
            title: const Text('Clear clipboard'),
            subtitle: const Text('Remove copied secrets automatically'),
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: settings.clipboardClearSeconds,
                onChanged: (seconds) {
                  if (seconds != null) {
                    settings.setClipboardClearSeconds(seconds);
                  }
                },
                items: const [
                  DropdownMenuItem(value: 15, child: Text('15 sec')),
                  DropdownMenuItem(value: 30, child: Text('30 sec')),
                  DropdownMenuItem(value: 60, child: Text('60 sec')),
                  DropdownMenuItem(value: 0, child: Text('Never')),
                ],
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Biometric unlock'),
            subtitle: Text(
              auth.isBiometricAvailable
                  ? 'Use fingerprint or face ID to unlock'
                  : 'Not available on this device',
            ),
            value: auth.biometricEnabled,
            onChanged: auth.isBiometricAvailable
                ? (value) => _toggleBiometric(context, value)
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Change master password'),
            subtitle: const Text('Re-encrypt the vault with a new password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _changeMasterPassword(context),
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Lock vault now'),
            onTap: session.lock,
          ),
          const Divider(),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.security),
            title: Text('Vault encryption'),
            subtitle: Text('AES-256-CBC + HMAC-SHA256'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ChangeMasterPasswordDialog extends StatefulWidget {
  const _ChangeMasterPasswordDialog();

  @override
  State<_ChangeMasterPasswordDialog> createState() =>
      _ChangeMasterPasswordDialogState();
}

class _ChangeMasterPasswordDialogState
    extends State<_ChangeMasterPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.changeMasterPassword(
      oldPassword: _oldController.text,
      newPassword: _newController.text,
    );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isLoading = false;
      _error =
          'Current password is incorrect, or the vault could not be '
          're-encrypted.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Master Password'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'The vault will be re-encrypted. If you forget the new '
                'password, the data cannot be recovered.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _oldController,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newController,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 12) return 'Use at least 12 characters';
                  if (v == _oldController.text) {
                    return 'Use a different password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v != _newController.text ? 'Passwords do not match' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Change'),
        ),
      ],
    );
  }
}
