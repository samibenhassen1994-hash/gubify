import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../repositories/gub_repository.dart';
import '../../modules/chat/widgets/gub_chat_overlay.dart';
import '../../widgets/gub_access_guard.dart';
import '../../widgets/gub_page_header.dart';
import '../../widgets/gub_screen_background.dart';

import 'widgets/gub_actions_section.dart';
import 'widgets/gub_board_button.dart';
import 'widgets/gub_dashboard_section.dart';
import 'widgets/gub_members_badge.dart';
import 'widgets/invite_code_card.dart';
import 'widgets/members_card.dart';
import 'widgets/modules_card.dart';

class GubScreen extends StatelessWidget {
  final String gubId;

  const GubScreen({super.key, required this.gubId});

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.tasks,
      child: GubChatOverlay(
        key: ValueKey(gubId),
        gubId: gubId,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: GubAccessGuard(
            gubId: gubId,
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: GubRepository.instance.hubStream(gubId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text("Hub not found"));
                }

                final data = snapshot.data!.data()!;

                final String gubName = data["name"] ?? "Hub";
                final String inviteCode = data["inviteCode"] ?? "";
                final String ownerId = data["ownerId"] ?? "";
                final int memberCount = data["memberCount"] ?? 1;

                final modules = Map<String, dynamic>.from(
                  data["modules"] ?? {},
                );

                final activeModules = modules.entries
                    .where((entry) => entry.value == true)
                    .map((entry) => entry.key)
                    .toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GubPageHeader(
                        title: gubName,
                        gubId: gubId,
                        userHeaderInCard: true,
                      ),

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
                        activeModules: activeModules,
                      ),

                      const SizedBox(height: 12),

                      MembersCard(gubId: gubId, memberCount: memberCount),

                      const SizedBox(height: 12),

                      ModulesCard(gubId: gubId, activeModules: activeModules),

                      const SizedBox(height: 12),

                      InviteCodeCard(inviteCode: inviteCode),

                      const SizedBox(height: 30),

                      GubActionsSection(gubId: gubId),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
