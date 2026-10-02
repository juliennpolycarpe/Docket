import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../profile.dart';
import '../widgets/connected_accounts.dart';
import '../widgets/user_avatar.dart';

const _maxAvatarBytes = 5 * 1024 * 1024; // matches the bucket limit in the migration
const _imageTypes = {'png': 'image/png', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'webp': 'image/webp', 'gif': 'image/gif'};

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Settings', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 20),
              const _Section(title: 'Profile', child: _ProfileSettings()),
              const _Section(title: 'Password', child: _PasswordSettings()),
              const _Section(title: 'Connected accounts', child: ConnectedAccounts()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _ProfileSettings extends StatefulWidget {
  const _ProfileSettings();

  @override
  State<_ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<_ProfileSettings> {
  late final _name = TextEditingController(text: fullName(supabase.auth.currentUser));
  bool _savingName = false;
  bool _uploading = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    setState(() => _savingName = true);
    try {
      await supabase.auth.updateUser(UserAttributes(data: {'full_name': _name.text.trim()}));
      if (mounted) _showMessage(context, 'Name saved.');
    } catch (_) {
      if (mounted) _showMessage(context, "Couldn't save your name. Try again.");
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _changePhoto() async {
    final file = await FilePicker.pickFile(type: FileType.image, dialogTitle: 'Choose a profile picture');
    if (file == null || !mounted) return;
    final extension = (file.extension ?? '').toLowerCase();
    final contentType = _imageTypes[extension];
    if (contentType == null) {
      _showMessage(context, 'Use a PNG, JPG, WebP or GIF image.');
      return;
    }

    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxAvatarBytes) {
        if (mounted) _showMessage(context, 'That image is too big. Pick one under 5 MB.');
        return;
      }
      final user = supabase.auth.currentUser!;
      final path = '${user.id}/avatar.$extension';
      final bucket = supabase.storage.from('avatars');
      await bucket.uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true, contentType: contentType));
      // The version parameter makes every device fetch the new picture instead of a cached one.
      final url = '${bucket.getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
      await supabase.auth.updateUser(UserAttributes(data: {'avatar_url': url}));
    } catch (_) {
      if (mounted) _showMessage(context, "Couldn't upload that picture. Try again.");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removePhoto() async {
    try {
      await supabase.auth.updateUser(UserAttributes(data: {'avatar_url': null}));
    } catch (_) {
      if (mounted) _showMessage(context, "Couldn't remove your picture. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = supabase.auth.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            UserAvatar(user: user, radius: 36),
            const SizedBox(width: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _changePhoto,
                  icon: _uploading
                      ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.photo_camera_outlined),
                  label: const Text('Change photo'),
                ),
                if (avatarUrl(user) != null) TextButton(onPressed: _removePhoto, child: const Text('Remove')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                onSubmitted: (_) => _saveName(),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton(onPressed: _savingName ? null : _saveName, child: const Text('Save')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Email: ${user?.email ?? ''}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _PasswordSettings extends StatefulWidget {
  const _PasswordSettings();

  @override
  State<_PasswordSettings> createState() => _PasswordSettingsState();
}

class _PasswordSettingsState extends State<_PasswordSettings> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = "The passwords don't match.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await supabase.auth.updateUser(UserAttributes(password: _password.text));
      _password.clear();
      _confirm.clear();
      if (mounted) _showMessage(context, 'Password updated.');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = "Couldn't update your password. Try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: const InputDecoration(labelText: 'New password', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: const InputDecoration(labelText: 'Confirm new password', border: OutlineInputBorder()),
          onSubmitted: (_) => _save(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(onPressed: _saving ? null : _save, child: const Text('Update password')),
        ),
      ],
    );
  }
}
