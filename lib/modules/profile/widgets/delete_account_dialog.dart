import 'package:flutter/material.dart';

import '../models/account_deletion_model.dart';
import '../services/account_deletion_service.dart';

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({
    super.key,
    required this.service,
    required this.requiresPassword,
  });

  final AccountDeletionService service;
  final bool requiresPassword;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _confirmation = TextEditingController();
  final _password = TextEditingController();
  bool _running = false;
  String? _error;

  @override
  void dispose() {
    _confirmation.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_running || _confirmation.text.trim() != 'DELETE') return;
    setState(() {
      _running = true;
      _error = null;
    });
    final result = await widget.service.deleteAccount(
      password: widget.requiresPassword ? _password.text : null,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _running = false;
      _error = _message(result.status);
    });
  }

  String _message(AccountDeletionStatus status) => switch (status) {
    AccountDeletionStatus.wrongPassword => 'The password is incorrect.',
    AccountDeletionStatus.wrongGoogleAccount =>
      'Please authenticate with the Google account linked to this Gubify account.',
    AccountDeletionStatus.reauthenticationCancelled =>
      'Account verification was cancelled.',
    AccountDeletionStatus.ownershipBlocked =>
      "You can't delete your account while you own a Gub or Community.",
    AccountDeletionStatus.authDeletionFailed =>
      "Account deletion couldn't be completed. Please retry.",
    _ => "Account deletion couldn't be completed. Please retry.",
  };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_running,
      child: AlertDialog(
        title: const Text('Delete account?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Your account and personal data will be permanently deleted. '
                'Shared chat messages will remain and will appear as "Deleted user".',
              ),
              const SizedBox(height: 16),
              if (widget.requiresPassword) ...[
                TextField(
                  controller: _password,
                  obscureText: true,
                  enabled: !_running,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _confirmation,
                enabled: !_running,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Type DELETE to confirm',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _running ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: !_running && _confirmation.text.trim() == 'DELETE'
                ? _delete
                : null,
            child: _running
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Delete account'),
          ),
        ],
      ),
    );
  }
}

class AccountDeletionBlockedDialog extends StatelessWidget {
  const AccountDeletionBlockedDialog({super.key, required this.preflight});

  final AccountDeletionPreflight preflight;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Account deletion unavailable'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "You can't delete your account while you own a Gub or Community.",
            ),
            if (preflight.privateGubs.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Private Gubs',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              for (final item in preflight.privateGubs) Text('• ${item.name}'),
            ],
            if (preflight.communities.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Communities',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              for (final item in preflight.communities) Text('• ${item.name}'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
