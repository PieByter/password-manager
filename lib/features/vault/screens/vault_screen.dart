import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/clipboard_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../domain/entities/password_entry.dart';
import '../../auth/providers/auth_provider.dart';
import '../../entry/screens/entry_screen.dart';
import '../../session/providers/session_provider.dart';
import '../../settings/screens/settings_screen.dart';
import '../providers/vault_provider.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _lock() {
    context.read<SessionProvider>().lock();
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _addEntry() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EntryScreen()));
  }

  void _viewEntry(String id) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EntryScreen(entryId: id)));
  }

  Future<void> _deleteEntry(String id) async {
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
    if (confirmed != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final vault = context.read<VaultProvider>();
    await vault.deleteEntry(id, auth.masterPassword!);
    if (mounted) {
      showSnackBar(context, 'Password deleted');
    }
  }

  Future<void> _copyToClipboard(String text, String label) async {
    if (text.isEmpty) return;
    final clipboard = context.read<ClipboardService>();
    await clipboard.copy(text);
    if (!mounted) return;

    final seconds = clipboard.clearSeconds;
    showSnackBar(
      context,
      seconds > 0 ? '$label copied — clears in ${seconds}s' : '$label copied',
    );
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final entries = vault.entries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Lock vault',
            onPressed: _lock,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search passwords...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          vault.searchQuery = '';
                        },
                      )
                    : null,
              ),
              onChanged: (v) => vault.searchQuery = v,
            ),
          ),
          // Password list
          Expanded(
            child: vault.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vault.errorMessage != null
                ? _buildErrorState(context, vault)
                : entries.isEmpty
                ? _buildEmptyState(context, vault)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _buildEntryCard(context, entry, vault);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        tooltip: 'Add password',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, VaultProvider vault) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not open the vault',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              vault.errorMessage ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                final password = context.read<AuthProvider>().masterPassword;
                if (password != null) {
                  vault.loadVault(password, force: true);
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, VaultProvider vault) {
    final isSearching = vault.searchQuery.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.lock_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? 'No results' : 'No passwords yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            isSearching
                ? 'Try a different search term'
                : 'Tap + to add your first password',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    PasswordEntry entry,
    VaultProvider vault,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            entry.title.isNotEmpty ? entry.title[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Flexible(
              child: Text(
                entry.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (entry.hasTotp) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.lock_outline,
                size: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 2),
              Text(
                '2FA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'copy_password') {
              _copyToClipboard(entry.password, 'Password');
            } else if (value == 'copy_username') {
              _copyToClipboard(entry.username, 'Username');
            } else if (value == 'delete') {
              _deleteEntry(entry.id);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'copy_password',
              child: ListTile(
                leading: Icon(Icons.copy),
                title: Text('Copy Password'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'copy_username',
              child: ListTile(
                leading: Icon(Icons.person),
                title: Text('Copy Username'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                dense: true,
              ),
            ),
          ],
        ),
        onTap: () => _viewEntry(entry.id),
      ),
    );
  }
}
