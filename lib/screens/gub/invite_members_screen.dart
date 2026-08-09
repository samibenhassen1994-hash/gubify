import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../repositories/gub_repository.dart';
import '../../services/gub_service.dart';
import '../../widgets/gub_content_card.dart';
import '../../widgets/gub_screen_background.dart';
import '../../widgets/user_header.dart';
import 'widgets/invite_code_panel.dart';

class InviteMembersScreen extends StatefulWidget {
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
  State<InviteMembersScreen> createState() => _InviteMembersScreenState();
}

class _InviteMembersScreenState extends State<InviteMembersScreen> {
  String? _currentInviteCode;

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
          future: (widget.loadGub ?? GubRepository.instance.getHubAuthoritatively)(
            widget.gubId,
          ),
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
            final inviteTokenId = _currentInviteCode ?? (hub["inviteTokenId"] as String? ?? "");
            final inviteAvailable = hub["deletionStatus"] != "deleting";
            final isOwner =
                hub['ownerId'] == FirebaseAuth.instance.currentUser?.uid;

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showUserHeader) UserHeader(gubId: widget.gubId),
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
                          if (isOwner && inviteAvailable) ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Regenerate invite?'),
                                    content: const Text(
                                      'Old invite links will stop working. Existing members will stay in this Gub.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Regenerate invite'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true || !context.mounted) {
                                  return;
                                }
                                try {
                                  final newCode = await GubService().regenerateInvite(
                                    gubId: widget.gubId,
                                  );
                                  if (!context.mounted) return;
                                  setState(() => _currentInviteCode = newCode);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Invite regenerated.'),
                                    ),
                                  );
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('$error')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Regenerate invite'),
                            ),
                          ],
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
                      stream: GubService().rawMembersStream(widget.gubId),
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
