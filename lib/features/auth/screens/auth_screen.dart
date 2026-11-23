// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/security/password_strength.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _useBiometric = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isSetup =>
      context.read<AuthProvider>().status == AuthStatus.needsSetup;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    bool success;

    if (_isSetup) {
      success = await auth.createMasterPassword(_passwordController.text);
      if (success && auth.isBiometricAvailable && _useBiometric) {
        await auth.toggleBiometric(true);
      }
    } else {
      success = await auth.login(_passwordController.text);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSetup ? 'Failed to setup password' : 'Invalid password',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _authenticateWithBiometric() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.loginWithBiometrics();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric authentication failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    final auth = context.watch<AuthProvider>();
    final isSetup = auth.status == AuthStatus.needsSetup;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSetup ? Icons.lock_outline : Icons.lock_open,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isSetup ? 'Create Master Password' : 'Welcome Back',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSetup
                        ? 'This password encrypts your entire vault. '
                              'It cannot be recovered if you forget it.'
                        : 'Enter your master password to unlock',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Master Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Password is required';
                      }
                      if (isSetup && v.length < 12) {
                        return 'Use at least 12 characters';
                      }
                      return null;
                    },
                  ),
                  if (isSetup)
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _passwordController,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) return const SizedBox.shrink();
                        final strength = PasswordStrength.estimate(value.text);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: strength.fraction,
                                  minHeight: 6,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  valueColor: AlwaysStoppedAnimation(
                                    _strengthColor(strength.score),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Strength: ${strength.label}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  if (isSetup) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                  if (isSetup && auth.isBiometricAvailable) ...[
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: _useBiometric,
                      onChanged: (v) =>
                          setState(() => _useBiometric = v ?? false),
                      title: const Text('Enable biometric unlock'),
                      subtitle: const Text('Fingerprint or face ID'),
                      secondary: const Icon(Icons.fingerprint),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isSetup ? 'Create Vault' : 'Unlock'),
                    ),
                  ),
                  if (!isSetup &&
                      auth.biometricEnabled &&
                      auth.isBiometricAvailable) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _authenticateWithBiometric,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Use Biometrics'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
