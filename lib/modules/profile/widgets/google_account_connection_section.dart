import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';

class GoogleAccountConnectionSection extends StatefulWidget {
  const GoogleAccountConnectionSection({super.key, required this.authService});

  final AuthService authService;

  @override
  State<GoogleAccountConnectionSection> createState() =>
      _GoogleAccountConnectionSectionState();
}

class _GoogleAccountConnectionSectionState
    extends State<GoogleAccountConnectionSection> {
  bool _isLinking = false;
  late bool _isGoogleLinked;
  bool _isAccountSecured = false;

  @override
  void initState() {
    super.initState();
    _isGoogleLinked = widget.authService.isGoogleLinked;
  }

  Future<void> _connectGoogle() async {
    if (_isLinking || _isGoogleLinked) return;

    setState(() => _isLinking = true);
    final result = await widget.authService
        .linkCurrentAnonymousUserWithGoogle();
    if (!mounted) return;

    setState(() => _isLinking = false);

    if (result.isSuccess) {
      setState(() {
        _isGoogleLinked = true;
        _isAccountSecured = true;
      });
      _showMessage(
        'Google account connected',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (result.status == GoogleLinkStatus.cancelled) return;

    _showMessage(_messageFor(result.status));
  }

  Future<void> _openEmailPasswordBind() async {
    final result = await showModalBottomSheet<EmailPasswordLinkResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _EmailPasswordBindSheet(authService: widget.authService),
    );
    if (!mounted || result == null) return;

    if (result.isSuccess) {
      setState(() => _isAccountSecured = true);
      _showMessage('Account secured', duration: const Duration(seconds: 3));
    }
  }

  void _showMessage(String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }

  String _messageFor(GoogleLinkStatus status) {
    return switch (status) {
      GoogleLinkStatus.credentialAlreadyInUse =>
        'This Google account is already linked to another Gubify account.',
      GoogleLinkStatus.accountExistsWithDifferentCredential =>
        'This Google account already belongs to an existing Gubify account.',
      GoogleLinkStatus.providerAlreadyLinked => 'Google account connected',
      GoogleLinkStatus.networkRequestFailed =>
        'Unable to connect Google. Check your internet connection and try again.',
      GoogleLinkStatus.operationNotAllowed =>
        'Google sign-in is not available right now.',
      GoogleLinkStatus.tooManyRequests =>
        'Too many attempts. Please try again later.',
      GoogleLinkStatus.noCurrentUser =>
        'Your account is not available right now. Please try again.',
      GoogleLinkStatus.invalidCredential ||
      GoogleLinkStatus.uidChanged ||
      GoogleLinkStatus.unknownFailure =>
        'Unable to connect your Google account. Please try again.',
      GoogleLinkStatus.success || GoogleLinkStatus.cancelled => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isAccountSecured ||
        _isGoogleLinked ||
        !widget.authService.isCurrentUserAnonymous) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFFE8F0FE),
                  child: Icon(Icons.security_rounded, color: Color(0xFF2563EB)),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Secure your account',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Connect Google to keep your Gubify account and access it on other devices.',
              style: TextStyle(color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLinking ? null : _connectGoogle,
                icon: _isLinking
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login_rounded),
                label: const Text('Continue with Google'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLinking ? null : _openEmailPasswordBind,
                icon: const Icon(Icons.email_outlined),
                label: const Text('Create email & password login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailPasswordBindSheet extends StatefulWidget {
  const _EmailPasswordBindSheet({required this.authService});

  final AuthService authService;

  @override
  State<_EmailPasswordBindSheet> createState() =>
      _EmailPasswordBindSheetState();
}

class _EmailPasswordBindSheetState extends State<_EmailPasswordBindSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    final result = await widget.authService.linkCurrentUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.isSuccess) {
      Navigator.of(context).pop(result);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_messageFor(result.status))));
  }

  String _messageFor(EmailPasswordLinkStatus status) {
    return switch (status) {
      EmailPasswordLinkStatus.invalidEmail => 'Enter a valid email address.',
      EmailPasswordLinkStatus.weakPassword =>
        'Choose a stronger password and try again.',
      EmailPasswordLinkStatus.emailAlreadyInUse ||
      EmailPasswordLinkStatus.credentialAlreadyInUse =>
        'This email is already linked to another Gubify account.',
      EmailPasswordLinkStatus.providerAlreadyLinked =>
        'An email and password login is already connected.',
      EmailPasswordLinkStatus.requiresRecentLogin =>
        'Please try again to secure your account.',
      EmailPasswordLinkStatus.networkRequestFailed =>
        'Check your internet connection and try again.',
      EmailPasswordLinkStatus.tooManyRequests =>
        'Too many attempts. Please try again later.',
      _ => 'Unable to secure your account. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create email & password login',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty || !email.contains('@')) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Enter a password.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(labelText: 'Confirm password'),
              validator: (value) => value != _passwordController.text
                  ? 'Passwords do not match.'
                  : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create login'),
            ),
          ],
        ),
      ),
    );
  }
}
