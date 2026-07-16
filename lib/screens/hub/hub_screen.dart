import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../repositories/hub_repository.dart';
import '../../widgets/hub_access_guard.dart';
import '../../widgets/hub_home_background.dart';
import '../../widgets/hub_page_header.dart';

import 'widgets/hub_actions_section.dart';
import 'widgets/hub_members_badge.dart';
import 'widgets/hub_modules_section.dart';
import 'widgets/invite_code_card.dart';
import 'widgets/members_card.dart';
import 'widgets/modules_card.dart';

class HubScreen extends StatelessWidget {
  final String hubId;

  const HubScreen({super.key, required this.hubId});

  @override
  Widget build(BuildContext context) {
    return HubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: HubAccessGuard(
          hubId: hubId,
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: HubRepository.instance.hubStream(hubId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text("Hub not found"));
              }

              final data = snapshot.data!.data()!;

              final String hubName = data["name"] ?? "Hub";
              final String inviteCode = data["inviteCode"] ?? "";
              final String ownerId = data["ownerId"] ?? "";
              final int memberCount = data["memberCount"] ?? 1;

              final modules = Map<String, dynamic>.from(data["modules"] ?? {});

              final activeModules = modules.entries
                  .where((entry) => entry.value == true)
                  .map((entry) => entry.key)
                  .toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HubPageHeader(title: hubName, hubId: hubId),

                    HubMembersBadge(memberCount: memberCount),

                    const SizedBox(height: 22),

                    HubModulesSection(
                      hubId: hubId,
                      memberCount: memberCount,
                      ownerId: ownerId,
                      activeModules: activeModules,
                    ),

                    MembersCard(hubId: hubId, memberCount: memberCount),

                    const SizedBox(height: 12),

                    ModulesCard(hubId: hubId, activeModules: activeModules),

                    const SizedBox(height: 12),

                    InviteCodeCard(inviteCode: inviteCode),

                    const SizedBox(height: 30),

                    HubActionsSection(hubId: hubId),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
