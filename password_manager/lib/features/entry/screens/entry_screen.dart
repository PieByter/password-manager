import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/helpers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../vault/providers/vault_provider.dart';

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
          masterPassword: auth.masterPassword!,
          salt: auth.salt!,
        );
      } else {
        await vault.addEntry(
          title: _titleController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          url: _urlController.text.trim(),
          notes: _notesController.text.trim(),
          masterPassword: auth.masterPassword!,
          salt: auth.salt!,
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
      await vault.deleteEntry(
        widget.entryId!,
        auth.masterPassword!,
        auth.salt!,
      );
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

  @override
  Widget build(BuildContext context) {
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
