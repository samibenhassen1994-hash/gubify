import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../profile/widgets/google_account_connection_section.dart';

typedef CommunityLinkedAccountGate =
    Future<bool> Function(BuildContext context);

Future<bool> showCommunityLinkedAccountGate(
  BuildContext context, {
  AuthService? authService,
}) async {
  final service = authService ?? AuthService();
  if (!service.isCurrentUserAnonymous) return true;

  return await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => SafeArea(
          child: Dialog(
            backgroundColor: Colors.white,
            elevation: 4,
            shadowColor: const Color(0xFF1E3A8A).withValues(alpha: 0.12),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F0FE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.link_rounded,
                        color: Color(0xFF2563EB),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Link your account',
                      textAlign: TextAlign.center,
                      style: Theme.of(dialogContext).textTheme.titleLarge
                          ?.copyWith(
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Link your account to join communities and keep your activity connected.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    GoogleAccountConnectionSection(
                      authService: service,
                      onAccountSecured: () =>
                          Navigator.of(dialogContext).pop(true),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: const Color(0xFF64748B),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Not now'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ) ??
      false;
}
