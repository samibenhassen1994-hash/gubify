import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/member_service.dart';
import '../../widgets/gub_content_card.dart';
import '../../widgets/gub_screen_background.dart';
import '../../modules/profile/screens/user_profile_screen.dart';
import 'my_gubs_screen.dart';

class MembersScreen extends StatelessWidget {
  final String gubId;
  final String ownerId;

  const MembersScreen({super.key, required this.gubId, required this.ownerId});

  Future<void> _leaveGub(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave Gub?'),
        content: const Text('You will lose access to this Gub.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    try {
      await MemberService.instance.leaveGub(gubId: gubId);
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MyGubsScreen()),
        (_) => false,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    final bool isOwner = currentUser != null && currentUser.uid == ownerId;

    return GubScreenBackground(
      variant: GubBackgroundAssignments.tasks,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Members"),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("gubs")
              .doc(gubId)
              .collection("members")
              .orderBy("joinedAt")
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: GubContentCard(
                  child: Text("No members found.", textAlign: TextAlign.center),
                ),
              );
            }

            final members = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index].data() as Map<String, dynamic>;

                final uid = member["uid"];

                final bool isMe = currentUser != null && currentUser.uid == uid;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: GubMemberAvatar(gubId: gubId, userId: uid),
                    title: Text(member["displayName"] ?? "User"),
                    subtitle: Text(isMe ? "You" : (member["role"] ?? "Member")),

                    trailing: isMe && !isOwner
                        ? TextButton(
                            onPressed: () => _leaveGub(context),
                            child: const Text('Leave'),
                          )
                        : isOwner && !isMe
                        ? PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value != "remove" && value != 'ban') {
                                return;
                              }

                              final confirm =
                                  await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Remove member"),
                                      content: Text(
                                        "${value == 'ban' ? 'Ban' : 'Remove'} ${member["displayName"]} from this Gub?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context, false);
                                          },
                                          child: const Text("Cancel"),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.pop(context, true);
                                          },
                                          child: Text(
                                            value == 'ban' ? 'Ban' : 'Remove',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;

                              if (!confirm) return;

                              if (value == 'ban') {
                                await MemberService.instance.banMember(
                                  gubId: gubId,
                                  uid: uid,
                                  currentUserId: currentUser.uid,
                                );
                              } else {
                                await MemberService.instance.removeMember(
                                  gubId: gubId,
                                  uid: uid,
                                  ownerId: ownerId,
                                  currentUserId: currentUser.uid,
                                );
                              }

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
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
                                    Text("Remove member"),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'ban',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.block_rounded,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 10),
                                    Text('Ban'),
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
      ),
    );
  }
}

class GubMemberAvatar extends StatelessWidget {
  const GubMemberAvatar({
    super.key,
    required this.gubId,
    required this.userId,
    this.profileScreenBuilder,
  });

  final String gubId;
  final String userId;
  final Widget Function(String gubId, String userId)? profileScreenBuilder;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('gub-member-avatar-$userId'),
    customBorder: const CircleBorder(),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            profileScreenBuilder?.call(gubId, userId) ??
            UserProfileScreen(gubId: gubId, userId: userId),
      ),
    ),
    child: CircleAvatar(
      backgroundColor: Colors.blue.shade100,
      child: const Icon(Icons.person),
    ),
  );
}
