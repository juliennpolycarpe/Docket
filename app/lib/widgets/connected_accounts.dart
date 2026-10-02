import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../main.dart';

/// Connected accounts list plus "add an account" options, for the Settings page.
class ConnectedAccounts extends StatefulWidget {
  const ConnectedAccounts({super.key});

  @override
  State<ConnectedAccounts> createState() => _ConnectedAccountsState();
}

class _ConnectedAccountsState extends State<ConnectedAccounts> {
  late Future<List<Map<String, dynamic>>> _accounts = _load();

  Future<List<Map<String, dynamic>>> _load() => supabase.from('connected_accounts').select().order('created_at');

  void _reload() => setState(() => _accounts = _load());

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _connectCanvas() async {
    final connected = await showDialog<_ConnectResult>(context: context, builder: (_) => const _ConnectCanvasDialog());
    if (connected == null) return;
    _reload();
    _showMessage(connected.syncWarning == null
        ? 'Canvas connected. Your assignments are on the To Do page.'
        : 'Canvas connected, but the first sync failed: ${connected.syncWarning}');
  }

  Future<void> _disconnect(Map<String, dynamic> account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect account?'),
        content: Text('${account['display_name']} will be removed from Docket, along with everything synced from it.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Disconnect')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DocketApi.disconnectAccount(account['id'] as String);
      _reload();
    } on ApiException catch (e) {
      _showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _accounts,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text("Couldn't load your accounts.");
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final accounts = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (accounts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('No accounts connected yet.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              ),
            for (final account in accounts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_providerIcon(account['provider'] as String)),
                title: Text(account['display_name'] as String),
                subtitle: _syncStatus(account, theme),
                trailing: IconButton(
                  tooltip: 'Disconnect',
                  icon: const Icon(Icons.link_off),
                  onPressed: () => _disconnect(account),
                ),
              ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.school),
              title: const Text('Connect Canvas'),
              subtitle: const Text('Assignments go to To Do'),
              trailing: const Icon(Icons.add),
              onTap: _connectCanvas,
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: false,
              leading: Icon(Icons.business_center),
              title: Text('Connect Outlook'),
              subtitle: Text('Coming soon'),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: false,
              leading: Icon(Icons.alternate_email),
              title: Text('Connect Google'),
              subtitle: Text('Coming soon'),
            ),
          ],
        );
      },
    );
  }

  Widget _syncStatus(Map<String, dynamic> account, ThemeData theme) {
    final error = account['last_sync_error'] as String?;
    if (error != null) return Text('Sync failed: $error', style: TextStyle(color: theme.colorScheme.error));
    final synced = account['last_synced_at'] as String?;
    if (synced == null) return const Text('Not synced yet');
    return Text('Last synced ${DateFormat.MMMd().add_jm().format(DateTime.parse(synced).toLocal())}');
  }
}

IconData _providerIcon(String provider) => switch (provider) {
      'canvas' => Icons.school,
      'microsoft' => Icons.business_center,
      _ => Icons.alternate_email,
    };

class _ConnectResult {
  _ConnectResult(this.syncWarning);
  final String? syncWarning;
}

class _ConnectCanvasDialog extends StatefulWidget {
  const _ConnectCanvasDialog();

  @override
  State<_ConnectCanvasDialog> createState() => _ConnectCanvasDialogState();
}

class _ConnectCanvasDialogState extends State<_ConnectCanvasDialog> {
  final _address = TextEditingController();
  final _token = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_address.text.trim().isEmpty || _token.text.trim().isEmpty) {
      setState(() => _error = 'Fill in both fields.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final warning = await DocketApi.connectCanvas(baseUrl: _address.text, token: _token.text);
      if (mounted) Navigator.of(context).pop(_ConnectResult(warning));
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Connect Canvas'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _address,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Canvas address', hintText: 'canvas.yourschool.edu'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _token,
              decoration: const InputDecoration(labelText: 'Access token'),
              obscureText: true,
              onSubmitted: (_) => _connect(),
            ),
            const SizedBox(height: 12),
            Text(
              'To get a token: in Canvas, open Account > Settings, click "+ New Access Token", '
              'give it a name like "Docket", then copy the token it shows you.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _connect,
          child: _busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Connect'),
        ),
      ],
    );
  }
}
