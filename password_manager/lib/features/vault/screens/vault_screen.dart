import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/helpers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../entry/screens/entry_screen.dart';
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

  void _logout() {
    context.read<AuthProvider>().logout();
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
    final auth = context.read<AuthProvider>();
    final vault = context.read<VaultProvider>();
    await vault.deleteEntry(id, auth.masterPassword!, auth.salt!);
    if (mounted) {
      showSnackBar(context, 'Password deleted');
    }
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      showSnackBar(context, '$label copied');
    }
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
            icon: const Icon(Icons.logout),
            tooltip: 'Lock vault',
            onPressed: _logout,
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
                : entries.isEmpty
                ? _buildEmptyState(context)
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No passwords yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first password',
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
    dynamic entry,
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
        subtitle: Text(
          entry.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
