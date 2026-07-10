import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../repositories/hub_repository.dart';
import '../../widgets/user_header.dart';
import '../../modules/goals/widgets/goal_home_card.dart';

import '../welcome_screen.dart';

import 'widgets/board_card.dart';
import 'widgets/invite_code_card.dart';
import 'widgets/invite_members_button.dart';
import 'widgets/manage_hub_button.dart';
import 'widgets/members_card.dart';
import 'widgets/modules_card.dart';
import '../../widgets/hub_access_guard.dart';

class HubScreen extends StatelessWidget {
  final String hubId;

  const HubScreen({
    super.key,
    required this.hubId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const WelcomeScreen(),
              ),
            );
          },
        ),
        title: const Text("Hubfy"),
      ),
      body: HubAccessGuard(
  hubId: hubId,
  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: HubRepository.instance.hubStream(hubId),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(
              child: Text("Hub not found"),
            );
          }

          final data = snapshot.data!.data()!;

          final String hubName =
              data["name"] ?? "Hub";

          final String inviteCode =
              data["inviteCode"] ?? "";

          final int memberCount =
              data["memberCount"] ?? 1;

          final String ownerId =
              data["ownerId"] ?? "";

          final Map<String, dynamic> modules =
              Map<String, dynamic>.from(
            data["modules"] ?? {},
          );

          final activeModules = modules.entries
              .where((e) => e.value == true)
              .map((e) => e.key)
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                 UserHeader(
                   hubId: hubId,
                    ),

                Text(
                  hubName,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  "Welcome to your Hub",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 30),

                BoardCard(
                  hubId: hubId,
                ),

                const SizedBox(height: 12),

                GoalHomeCard(
                  hubId: hubId,
                  ownerId: ownerId,
                ),

                const SizedBox(height: 12),

                MembersCard(
                  hubId: hubId,
                  memberCount: memberCount,
                ),

                const SizedBox(height: 12),

                ModulesCard(
                  hubId: hubId,
                  activeModules: activeModules,
                ),

                const SizedBox(height: 12),

                InviteCodeCard(
                  inviteCode: inviteCode,
                ),

                const SizedBox(height: 30),

                InviteMembersButton(
                  hubId: hubId,
                ),

                const SizedBox(height: 15),

                ManageHubButton(
                  hubId: hubId,
                ),
              ],
            ),
                  );
      },
    ),
  ),
);
}
}