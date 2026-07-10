import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/member_service.dart';

class MembersScreen extends StatelessWidget {
  final String hubId;
  final String ownerId;

  const MembersScreen({
    super.key,
    required this.hubId,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    final bool isOwner =
        currentUser != null &&
        currentUser.uid == ownerId;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Members"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("hubs")
            .doc(hubId)
            .collection("members")
            .orderBy("joinedAt")
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No members found."),
            );
          }

          final members = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member =
                  members[index].data()
                      as Map<String, dynamic>;

              final uid = member["uid"];

              final bool isMe =
                  currentUser != null &&
                  currentUser.uid == uid;

              return Card(
                elevation: 0,
                margin:
                    const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Colors.blue.shade100,
                    child: const Icon(Icons.person),
                  ),
                  title: Text(
                    member["displayName"] ??
                        "User",
                  ),
                  subtitle: Text(
                    isMe
                        ? "You"
                        : (member["role"] ??
                            "Member"),
                  ),

                  trailing: isOwner && !isMe
                      ? PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value != "remove") {
                              return;
                            }

                            final confirm =
                                await showDialog<bool>(
                                      context: context,
                                      builder: (_) =>
                                          AlertDialog(
                                        title: const Text(
                                          "Remove member",
                                        ),
                                        content: Text(
                                          "Remove ${member["displayName"]} from this Hub?",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(
                                                  context,
                                                  false);
                                            },
                                            child:
                                                const Text(
                                              "Cancel",
                                            ),
                                          ),
                                          FilledButton(
                                            onPressed: () {
                                              Navigator.pop(
                                                  context,
                                                  true);
                                            },
                                            child:
                                                const Text(
                                              "Remove",
                                            ),
                                          ),
                                        ],
                                      ),
                                    ) ??
                                    false;

                            if (!confirm) return;

                            await MemberService.instance.removeMember(
  hubId: hubId,
  uid: uid,
  ownerId: ownerId,
  currentUserId: currentUser!.uid,
);

                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                      context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "${member["displayName"]} removed.",
                                  ),
                                ),
                              );
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: "remove",
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_remove,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                      "Remove member"),
                                ],
                              ),
                            ),
                          ],
                        )
                      : member["role"] == "Owner"
                          ? const Icon(
                              Icons.workspace_premium,
                              color: Colors.amber,
                            )
                          : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}