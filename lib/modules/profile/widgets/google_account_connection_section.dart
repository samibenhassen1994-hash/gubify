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
    if (_isGoogleLinked || !widget.authService.isCurrentUserAnonymous) {
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
          ],
        ),
      ),
    );
  }
}
