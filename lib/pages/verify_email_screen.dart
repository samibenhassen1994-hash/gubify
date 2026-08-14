import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/startup_artwork_background.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.authService,
    required this.onVerified,
    required this.onUseAnotherAccount,
  });

  final AuthService authService;
  final Future<void> Function() onVerified;
  final Future<void> Function() onUseAnotherAccount;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _cooldownTimer;
  bool _isChecking = false;
  bool _isResending = false;
  bool _isSwitchingAccount = false;
  int _resendSeconds = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    if (_isChecking || _isSwitchingAccount) return;
    setState(() => _isChecking = true);
    final result = await widget.authService.reloadCurrentUser();
    if (!mounted) return;

    if (result.isVerified) {
      try {
        await widget.onVerified();
      } on Object {
        if (mounted) {
          setState(() => _isChecking = false);
          _showMessage('Unable to continue. Please try again.');
        }
      }
      return;
    }

    setState(() => _isChecking = false);
    _showMessage(_messageFor(result.status));
  }

  Future<void> _resendVerification() async {
    if (_isResending || _isChecking || _resendSeconds > 0) return;
    setState(() => _isResending = true);
    final result = await widget.authService.sendCurrentUserEmailVerification();
    if (!mounted) return;
    setState(() => _isResending = false);

    if (result.isSuccess) {
      _startResendCooldown();
      _showMessage('Verification email sent.');
      return;
    }
    _showMessage(_messageFor(result.status));
  }

  Future<void> _useAnotherAccount() async {
    if (_isSwitchingAccount || _isChecking || _isResending) return;
    setState(() => _isSwitchingAccount = true);
    try {
      await widget.onUseAnotherAccount();
    } on Object {
      if (mounted) _showMessage('Unable to switch accounts. Please try again.');
    } finally {
      if (mounted) setState(() => _isSwitchingAccount = false);
    }
  }

  void _startResendCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds -= 1);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageFor(EmailVerificationStatus status) {
    return switch (status) {
      EmailVerificationStatus.notVerified => 'Email not verified yet.',
      EmailVerificationStatus.noCurrentUser =>
        'Your account is no longer available. Please sign in again.',
      EmailVerificationStatus.networkRequestFailed =>
        'Check your internet connection and try again.',
      EmailVerificationStatus.tooManyRequests =>
        'Too many requests. Please try again later.',
      _ => 'Unable to verify your email. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.authService.currentUserEmail ?? 'your email address';
    final isBusy = _isChecking || _isResending || _isSwitchingAccount;

    return StartupArtworkBackground(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      color: Color(0xFF2563EB),
                      size: 38,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Verify your email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'We sent a verification link to',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Open the link in your email, then come back here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF475569), height: 1.35),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: isBusy ? null : _checkVerification,
                      child: _isChecking
                          ? const _ButtonProgress()
                          : const Text("I've verified my email"),
                    ),
                    TextButton(
                      onPressed: isBusy || _resendSeconds > 0
                          ? null
                          : _resendVerification,
                      child: _isResending
                          ? const _ButtonProgress(color: Color(0xFF2563EB))
                          : Text(
                              _resendSeconds > 0
                                  ? 'Resend email in $_resendSeconds seconds'
                                  : 'Resend email',
                            ),
                    ),
                    TextButton(
                      onPressed: isBusy ? null : _useAnotherAccount,
                      child: const Text('Use another account'),
                    ),
                  ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonProgress extends StatelessWidget {
  const _ButtonProgress({this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}
