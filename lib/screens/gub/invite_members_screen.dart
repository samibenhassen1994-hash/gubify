import 'package:flutter/material.dart';

import '../../repositories/gub_repository.dart';
import '../../services/gub_service.dart';
import '../../widgets/gub_content_card.dart';
import '../../widgets/gub_screen_background.dart';
import '../../widgets/user_header.dart';
import 'widgets/invite_code_panel.dart';

class InviteMembersScreen extends StatelessWidget {
  final String gubId;
  final Future<Map<String, dynamic>?> Function(String gubId)? loadGub;
  final bool showUserHeader;

  const InviteMembersScreen({
    super.key,
    required this.gubId,
    this.loadGub,
    this.showUserHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.tasks,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Invite members"),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: FutureBuilder<Map<String, dynamic>?>(
          future: (loadGub ?? GubRepository.instance.getHub)(gubId),
          builder: (context, hubSnapshot) {
            if (hubSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (hubSnapshot.hasError ||
                !hubSnapshot.hasData ||
                hubSnapshot.data == null) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: GubContentCard(
                  child: Text(
                    "Invite unavailable. Please try again.",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final hub = hubSnapshot.data!;
            final gubName = hub["name"] as String? ?? "";
            final inviteTokenId = hub["inviteTokenId"] as String? ?? "";
            final inviteAvailable = hub["deletionStatus"] != "deleting";

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showUserHeader) UserHeader(gubId: gubId),
                    GubContentCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "Share this invite with people you want to add to this Gub.",
                            style: TextStyle(color: Colors.grey, fontSize: 17),
                          ),
                          const SizedBox(height: 24),
                          InviteCodePanel(
                            gubName: gubName,
                            canonicalCode: inviteTokenId,
                            inviteAvailable: inviteAvailable,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      "Members",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    StreamBuilder(
                      stream: GubService().rawMembersStream(gubId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const GubContentCard(
                            child: Text(
                              "No members yet",
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        return Column(
                          children: [
                            for (final document in snapshot.data!.docs)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  color: Colors.white,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.shade100,
                                      child: const Icon(Icons.person),
                                    ),
                                    title: Text(
                                      document.data()["displayName"] ?? "User",
                                    ),
                                    subtitle: Text(
                                      document.data()["role"] ?? "",
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
