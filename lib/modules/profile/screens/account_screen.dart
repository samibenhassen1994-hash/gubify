import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../pages/startup_screen.dart';
import '../models/account_details_model.dart';
import '../models/account_deletion_model.dart';
import '../services/account_service.dart';
import '../services/account_deletion_service.dart';
import '../widgets/delete_account_dialog.dart';
import '../widgets/google_account_connection_section.dart';
import '../../moderation/blocking/screens/blocked_users_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.authService,
    this.accountService,
    this.accountDeletionService,
    this.blockedUsersScreenBuilder,
  });

  final AuthService authService;
  final AccountService? accountService;
  final AccountDeletionService? accountDeletionService;
  final Widget Function()? blockedUsersScreenBuilder;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final AccountService _accountService;
  AccountDeletionService? _accountDeletionService;
  late Future<AccountDetailsModel?> _details;

  @override
  void initState() {
    super.initState();
    _accountService =
        widget.accountService ??
        AccountService(authService: widget.authService);
    _accountDeletionService = widget.accountDeletionService;
    _reload();
  }

  void _reload() {
    _details = _accountService.load();
  }

  Future<void> _changeName(AccountDetailsModel details) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _ChangeNameDialog(currentName: details.displayName),
    );
    if (!mounted || result == null) return;
    final change = await _accountService.changeDisplayName(
      current: details,
      displayName: result,
    );
    if (!mounted) return;
    if (change.isSuccess) {
      setState(_reload);
      _showMessage('Name changed.');
      return;
    }
    setState(_reload);
    _showMessage(_nameChangeMessage(change));
  }

  Future<void> _openAccountSecurity() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: GoogleAccountConnectionSection(authService: widget.authService),
      ),
    );
    if (mounted) setState(_reload);
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangePasswordDialog(authService: widget.authService),
    );
    if (mounted && changed == true) _showMessage('Password changed.');
  }

  Future<void> _deleteAccount() async {
    final deletionService = _accountDeletionService ??= AccountDeletionService(
      authService: widget.authService,
    );
    AccountDeletionPreflight preflight;
    try {
      preflight = await deletionService.preflight();
    } catch (_) {
      if (mounted) {
        _showMessage('Unable to check account ownership. Try again.');
      }
      return;
    }
    if (!mounted) return;
    if (preflight.isBlocked) {
      await showDialog<void>(
        context: context,
        builder: (_) => AccountDeletionBlockedDialog(preflight: preflight),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteAccountDialog(
        service: deletionService,
        requiresPassword: widget.authService.isPasswordLinked,
        onDeleted: (context) async {
          if (!context.mounted) return;
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
            MaterialPageRoute(
              builder: (_) => StartupScreen(
                authService: widget.authService,
                minimumDisplayDuration: Duration.zero,
                onNavigationReady: () {},
              ),
            ),
            (_) => false,
          );
        },
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _nameChangeMessage(NameChangeResult result) {
    return switch (result.status) {
      NameChangeStatus.cooldown || NameChangeStatus.permissionDenied
          when result.eligibleAt != null =>
        'You can change your name again on ${_formatDate(result.eligibleAt!)}.',
      NameChangeStatus.invalidName => 'Enter a name up to 22 characters.',
      NameChangeStatus.unchanged => 'Enter a different name.',
      _ => 'Unable to change your name right now. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: FutureBuilder<AccountDetailsModel?>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('Unable to load account details.'));
          }
          return _buildDetails(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildDetails(AccountDetailsModel details) {
    final providers = widget.authService.providerIds.toSet();
    final anonymous = widget.authService.isCurrentUserAnonymous;
    final hasGoogle = providers.contains('google.com');
    final hasPassword = providers.contains('password');
    final eligibleAt = _accountService.nextNameChangeAt(details);
    final canChangeName = _accountService.canChangeName(details);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _AccountCard(
          title: 'Name',
          value: details.displayName,
          action: TextButton(
            onPressed: canChangeName ? () => _changeName(details) : null,
            child: const Text('Change name'),
          ),
          note: !canChangeName && eligibleAt != null
              ? 'You can change your name again on ${_formatDate(eligibleAt)}.'
              : null,
        ),
        _AccountCard(
          title: 'Email',
          value: widget.authService.currentUserEmail ?? 'Not set',
        ),
        _AccountCard(
          title: 'Sign-in methods',
          child: Wrap(
            spacing: 8,
            children: [
              if (anonymous) const Chip(label: Text('Anonymous')),
              if (hasGoogle) const Chip(label: Text('Google')),
              if (hasPassword) const Chip(label: Text('Email')),
            ],
          ),
        ),
        if (anonymous || hasPassword)
          _AccountCard(
            title: 'Password',
            value: hasPassword ? '••••••••' : 'Not set',
            action: hasPassword
                ? TextButton(
                    onPressed: _changePassword,
                    child: const Text('Change password'),
                  )
                : TextButton(
                    onPressed: _openAccountSecurity,
                    child: const Text('Secure your account'),
                  ),
          ),
        _AccountCard(
          title: 'Blocked users',
          value: "Manage the people you've blocked.",
          action: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    widget.blockedUsersScreenBuilder?.call() ??
                    const BlockedUsersScreen(),
              ),
            ),
            child: const Text('Manage'),
          ),
        ),
        _AccountCard(
          title: 'Member since',
          value: details.createdAt == null
              ? 'Not available'
              : _formatDate(details.createdAt!.toDate()),
        ),
        Card(
          margin: const EdgeInsets.only(top: 12),
          color: const Color(0xFFFFF1F2),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Danger zone',
                  style: TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Permanently delete your account and personal data.',
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _deleteAccount,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                  ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Delete account'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.title,
    this.value,
    this.child,
    this.action,
    this.note,
  });

  final String title;
  final String? value;
  final Widget? child;
  final Widget? action;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            child ?? Text(value ?? ''),
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(note!, style: const TextStyle(color: Color(0xFF64748B))),
            ],
            if (action != null)
              Align(alignment: Alignment.centerLeft, child: action!),
          ],
        ),
      ),
    );
  }
}

class _ChangeNameDialog extends StatefulWidget {
  const _ChangeNameDialog({required this.currentName});
  final String currentName;

  @override
  State<_ChangeNameDialog> createState() => _ChangeNameDialogState();
}

class _ChangeNameDialogState extends State<_ChangeNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text.trim();
    return AlertDialog(
      title: const Text('Change name'),
      content: TextField(
        controller: _controller,
        maxLength: 22,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Name'),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: value.isEmpty || value == widget.currentName.trim()
              ? null
              : () => Navigator.pop(context, value),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.authService});
  final AuthService authService;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.authService.changePassword(
      currentPassword: _current.text,
      newPassword: _next.text,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _loading = false;
      _error = _passwordMessage(result.status);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _passwordField(_current, 'Current password'),
            _passwordField(
              _next,
              'New password',
              validator: (value) => (value?.length ?? 0) < 6
                  ? 'Use at least 6 characters.'
                  : null,
            ),
            _passwordField(
              _confirm,
              'Confirm new password',
              validator: (value) =>
                  value != _next.text ? 'Passwords do not match.' : null,
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Change password'),
        ),
      ],
    );
  }

  Widget _passwordField(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: true,
        decoration: InputDecoration(labelText: label),
        validator:
            validator ??
            (value) => (value?.isEmpty ?? true) ? 'Required.' : null,
      ),
    );
  }

  String _passwordMessage(PasswordChangeStatus status) => switch (status) {
    PasswordChangeStatus.wrongPassword => 'Current password is incorrect.',
    PasswordChangeStatus.weakPassword => 'Choose a stronger password.',
    PasswordChangeStatus.requiresRecentLogin =>
      'Please sign in again before changing your password.',
    PasswordChangeStatus.networkRequestFailed =>
      'Check your internet connection and try again.',
    PasswordChangeStatus.tooManyRequests =>
      'Too many attempts. Please try again later.',
    PasswordChangeStatus.noEmail => 'This account has no usable email address.',
    _ => 'Unable to change password right now. Please try again.',
  };
}

String _formatDate(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
