import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../models/account_deletion_model.dart';
import '../services/account_deletion_service.dart';

class AccountDeletionRecoveryScreen extends StatefulWidget {
  const AccountDeletionRecoveryScreen({
    super.key,
    required this.authService,
    required this.deletionService,
    required this.onCompleted,
  });

  final AuthService authService;
  final AccountDeletionService deletionService;
  final VoidCallback onCompleted;

  @override
  State<AccountDeletionRecoveryScreen> createState() =>
      _AccountDeletionRecoveryScreenState();
}

class _AccountDeletionRecoveryScreenState
    extends State<AccountDeletionRecoveryScreen> {
  final _password = TextEditingController();
  bool _running = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
    });
    final result = await widget.deletionService.deleteAccount(
      password: widget.authService.isPasswordLinked ? _password.text : null,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      widget.onCompleted();
      return;
    }
    setState(() {
      _running = false;
      _error = switch (result.status) {
        AccountDeletionStatus.wrongPassword => 'The password is incorrect.',
        AccountDeletionStatus.wrongGoogleAccount =>
          'Please authenticate with the Google account linked to this Gubify account.',
        AccountDeletionStatus.ownershipBlocked =>
          "Account deletion is blocked because this account still owns a Gub or Community.",
        _ => "Account deletion couldn't be completed. Please retry.",
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 42,
                          color: Color(0xFFB45309),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Account deletion wasn't completed.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Retry to safely finish removing your account.',
                          textAlign: TextAlign.center,
                        ),
                        if (widget.authService.isPasswordLinked) ...[
                          const SizedBox(height: 18),
                          TextField(
                            controller: _password,
                            obscureText: true,
                            enabled: !_running,
                            decoration: const InputDecoration(
                              labelText: 'Current password',
                            ),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _running ? null : _retry,
                          child: _running
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Retry deletion'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
