import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';

class AccountSessionSection extends StatefulWidget {
  const AccountSessionSection({
    super.key,
    required this.authService,
    required this.onLoggedOut,
    required this.onSecureAccount,
  });

  final AuthService authService;
  final Future<void> Function() onLoggedOut;
  final VoidCallback onSecureAccount;

  @override
  State<AccountSessionSection> createState() => _AccountSessionSectionState();
}

class _AccountSessionSectionState extends State<AccountSessionSection> {
  bool _isConfirming = false;
  bool _isLoggingOut = false;

  Future<void> _confirmLogOut() async {
    if (_isConfirming || _isLoggingOut) return;
    setState(() => _isConfirming = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _isConfirming = false);
    if (confirmed != true) return;

    setState(() => _isLoggingOut = true);
    final result = await widget.authService.logOut();
    if (!mounted) return;

    if (result.isSuccess) {
      await widget.onLoggedOut();
      return;
    }

    setState(() => _isLoggingOut = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_messageFor(result.status))),
    );
  }

  String _messageFor(LogoutStatus status) {
    return switch (status) {
      LogoutStatus.anonymousUser => 'To log out, secure your account first.',
      LogoutStatus.noCurrentUser || LogoutStatus.unknownFailure =>
        'Unable to log out right now. Please try again.',
      LogoutStatus.success => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.authService.isCurrentUserAnonymous) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'To log out, secure your account first.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connect Google or email to keep your account and data before signing out.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF475569), height: 1.4),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: widget.onSecureAccount,
                icon: const Icon(Icons.security_rounded),
                label: const Text('Secure your account'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isConfirming || _isLoggingOut ? null : _confirmLogOut,
            icon: _isLoggingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ),
      ),
    );
  }
}
