import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/totp/totp_service.dart';
import '../../../core/utils/helpers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../vault/providers/vault_provider.dart';
import '../widgets/totp_display.dart';

class EntryScreen extends StatefulWidget {
  final String? entryId;

  const EntryScreen({super.key, this.entryId});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _totpEnabled = false;
  String? _totpSecret; // stored once setup is complete
  bool get _isEditing => widget.entryId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadEntry();
    } else {
      _generatePassword();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadEntry() {
    final vault = context.read<VaultProvider>();
    final entry = vault.getEntryById(widget.entryId!);
    if (entry != null) {
      _titleController.text = entry.title;
      _usernameController.text = entry.username;
      _passwordController.text = entry.password;
      _urlController.text = entry.url;
      _notesController.text = entry.notes;
      if (entry.hasTotp) {
        _totpEnabled = true;
        _totpSecret = entry.totpSecret;
      }
    }
  }

  void _generatePassword() {
    final random = DateTime.now().microsecondsSinceEpoch;
    final chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    final password = List.generate(20, (i) {
      final index = (random * (i + 1)) % chars.length;
      return chars[index];
    }).join();
    _passwordController.text = password;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final vault = context.read<VaultProvider>();

    try {
      if (_isEditing) {
        await vault.updateEntry(
          id: widget.entryId!,
          title: _titleController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          url: _urlController.text.trim(),
          notes: _notesController.text.trim(),
          totpSecret: _totpSecret,
          clearTotp: _totpEnabled && _totpSecret == null,
          masterPassword: auth.masterPassword!,
        );
      } else {
        await vault.addEntry(
          title: _titleController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          url: _urlController.text.trim(),
          notes: _notesController.text.trim(),
          totpSecret: _totpSecret,
          masterPassword: auth.masterPassword!,
        );
      }

      if (mounted) {
        showSnackBar(
          context,
          _isEditing ? 'Password updated' : 'Password saved',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Error saving password');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAndGoBack() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Password'),
        content: const Text('Are you sure you want to delete this password?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final auth = context.read<AuthProvider>();
      final vault = context.read<VaultProvider>();
      await vault.deleteEntry(widget.entryId!, auth.masterPassword!);
      if (mounted) {
        showSnackBar(context, 'Password deleted');
        Navigator.of(context).pop();
      }
    }
  }

  void _copyField(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showSnackBar(context, '$label copied');
  }

  /// Opens a dialog to setup TOTP secret
  void _setupTotp() {
    final controller = TextEditingController();
    final isFromExisting = _isEditing && _totpEnabled && _totpSecret != null;

    if (isFromExisting) {
      // TOTP already setup — show remove option
      _showTotpManagement();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Setup 2FA (TOTP)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paste your secret key from the service (e.g. Google, GitHub), '
              'or auto-generate one.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Secret Key (Base32)',
                hintText: 'JBSWY3DPEHPK3PXP',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              maxLines: 2,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                controller.text = TotpService.generateSecret();
              },
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Generate Random Secret'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final secret = controller.text.trim();
              if (secret.isEmpty) return;
              if (!TotpService.isValidSecret(secret)) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid Base32 secret key'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              setState(() {
                _totpEnabled = true;
                _totpSecret = secret;
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Save Secret'),
          ),
        ],
      ),
    );
  }

  /// Shows TOTP management options when TOTP is already setup
  void _showTotpManagement() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('2FA (TOTP)'),
        content: const Text(
          'TOTP is currently enabled for this entry. '
          'You can remove it if you no longer need it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.tonalIcon(
            onPressed: () {
              setState(() {
                _totpEnabled = false;
                _totpSecret = null;
              });
              Navigator.of(ctx).pop();
              showSnackBar(context, 'TOTP removed (save to confirm)');
            },
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('Remove 2FA'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade100),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTotp = _totpEnabled && _totpSecret != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'View Password' : 'New Password'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete',
              onPressed: _deleteAndGoBack,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Google, GitHub',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Title is required' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Username
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                  suffixIcon: _isEditing
                      ? IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () =>
                              _copyField(_usernameController.text, 'Username'),
                        )
                      : null,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Username is required'
                    : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_isEditing)
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Generate password',
                          onPressed: _generatePassword,
                        ),
                      IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      if (_isEditing)
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () =>
                              _copyField(_passwordController.text, 'Password'),
                        ),
                    ],
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Password is required' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // URL
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Website URL (optional)',
                  hintText: 'https://',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 16),

              // ── TOTP / 2FA Section ──
              if (hasTotp) ...[
                TotpDisplay(secret: _totpSecret!),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _setupTotp,
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('Manage 2FA'),
                  ),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: _setupTotp,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Add Two-Factor Auth (2FA)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _save,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_isEditing ? Icons.save : Icons.add),
                  label: Text(_isEditing ? 'Update Password' : 'Save Password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
