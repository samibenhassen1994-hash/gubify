import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../repositories/gub_repository.dart';
import '../../core/invites/invite_code.dart';
import '../../services/gub_deletion_service.dart';
import '../../modules/chat/widgets/gub_chat_overlay.dart';
import '../../widgets/gub_access_guard.dart';
import '../../widgets/gub_community_rules_gate.dart';
import '../../widgets/gub_page_header.dart';
import '../../widgets/gub_screen_background.dart';

import 'gub_deletion_navigation.dart';
import 'widgets/gub_actions_section.dart';
import 'widgets/gub_board_button.dart';
import 'widgets/gub_dashboard_section.dart';
import 'widgets/gub_members_badge.dart';
import 'widgets/invite_code_card.dart';
import 'widgets/members_card.dart';

class GubScreen extends StatefulWidget {
  final String gubId;

  const GubScreen({super.key, required this.gubId});

  @override
  State<GubScreen> createState() => _GubScreenState();
}

class _GubScreenState extends State<GubScreen> {
  final GubDeletionNavigationController _deletionNavigation =
      GubDeletionNavigationController();

  void _scheduleExitFromDeletedGub({required bool showDeletionMessage}) {
    _deletionNavigation.scheduleExit(
      context,
      message: showDeletionMessage
          ? 'This Gub is being deleted by its owner.'
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gubId = widget.gubId;
    return GubScreenBackground(
      variant: GubBackgroundAssignments.tasks,
      child: GubAccessGuard(
        gubId: gubId,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: GubRepository.instance.hubStream(gubId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Colors.transparent,
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final data = snapshot.data?.data();
            final routeAction = resolveGubDeletionRouteAction(
              gubData: data,
              currentUserId: FirebaseAuth.instance.currentUser?.uid,
            );
            switch (routeAction) {
              case GubDeletionRouteAction.exitSilently:
                _scheduleExitFromDeletedGub(showDeletionMessage: false);
                return const Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Center(child: CircularProgressIndicator()),
                );
              case GubDeletionRouteAction.exitWithOwnerMessage:
                _scheduleExitFromDeletedGub(showDeletionMessage: true);
                return const Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Center(child: CircularProgressIndicator()),
                );
              case GubDeletionRouteAction.stay:
                break;
            }
            if (data!["deletionStatus"] == "deleting") {
              return _GubDeletionInProgress(gubId: gubId);
            }

            return GubCommunityRulesGate(
              gubId: gubId,
              child: GubChatOverlay(
                key: ValueKey(gubId),
                gubId: gubId,
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: _GubDashboard(gubId: gubId, data: data),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GubDeletionInProgress extends StatefulWidget {
  final String gubId;

  const _GubDeletionInProgress({required this.gubId});

  @override
  State<_GubDeletionInProgress> createState() => _GubDeletionInProgressState();
}

class _GubDeletionInProgressState extends State<_GubDeletionInProgress> {
  bool _running = false;
  String _progress = 'This Gub is being deleted.';

  Future<void> _resume() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      await GubDeletionService.instance.resumeDeletion(
        gubId: widget.gubId,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_forever_outlined, size: 42),
                const SizedBox(height: 16),
                const Text(
                  'Deletion in progress',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(_progress, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _running ? null : _resume,
                  child: _running
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Resume deletion'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _GubDashboard extends StatelessWidget {
  final String gubId;
  final Map<String, dynamic> data;

  const _GubDashboard({required this.gubId, required this.data});

  @override
  Widget build(BuildContext context) {
    final gubName = data["name"] as String? ?? "Hub";
    final inviteTokenId = data["inviteTokenId"] as String? ?? "";
    final inviteCode = InviteCode.tryFormat(inviteTokenId) ?? "Unavailable";
    final ownerId = data["ownerId"] as String? ?? "";
    final memberCount = data["memberCount"] as int? ?? 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GubPageHeader(title: gubName, gubId: gubId, userHeaderInCard: true),
          LayoutBuilder(
            builder: (context, constraints) {
              final boardButtonLeft = constraints.maxWidth / 2 + 70;
              return SizedBox(
                height: 54,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    GubMembersBadge(memberCount: memberCount),
                    Positioned(
                      left: boardButtonLeft,
                      child: GubBoardButton(gubId: gubId),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          GubDashboardSection(
            gubId: gubId,
            ownerId: ownerId,
            memberCount: memberCount,
          ),
          const SizedBox(height: 12),
          MembersCard(gubId: gubId, memberCount: memberCount),
          const SizedBox(height: 12),
          InviteCodeCard(inviteCode: inviteCode),
          const SizedBox(height: 30),
          GubActionsSection(gubId: gubId),
        ],
      ),
    );
  }
}
