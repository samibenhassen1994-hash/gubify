import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/goal_member_service.dart';
import 'my_contribution_screen.dart';

class GoalMembersScreen extends StatelessWidget {
  final String hubId;
  final String goalId;
  final String ownerId;

  const GoalMembersScreen({
    super.key,
    required this.hubId,
    required this.goalId,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    final isOwner = currentUser != null && currentUser.uid == ownerId;

    return Scaffold(
      appBar: AppBar(title: const Text("Participants")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: GoalMemberService.instance.membersStream(
          hubId: hubId,
          goalId: goalId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No participants found."));
          }

          final members = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final data = members[index].data();

              final uid = data["uid"];

              final amount = (data["amount"] ?? 0).toDouble();

              final confirmed = data["confirmed"] ?? false;

              final isMe = currentUser != null && currentUser.uid == uid;

              String status;
              Color statusColor;

              if (confirmed) {
                status = "Confirmed";
                statusColor = Colors.green;
              } else if (amount > 0) {
                status = "Waiting for confirmation";
                statusColor = Colors.orange;
              } else {
                status = "Not submitted";
                statusColor = Colors.grey;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: isMe
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MyContributionScreen(
                                hubId: hubId,
                                goalId: goalId,
                              ),
                            ),
                          );
                        }
                      : null,
                  leading: CircleAvatar(
                    child: Text((data["displayName"] ?? "U")[0].toUpperCase()),
                  ),
                  title: Text(data["displayName"] ?? "User"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text("Contribution: €${amount.toStringAsFixed(2)}"),
                      const SizedBox(height: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  trailing: isOwner && !confirmed && amount > 0
                      ? IconButton(
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          onPressed: () async {
                            await GoalMemberService.instance
                                .confirmContribution(
                                  hubId: hubId,
                                  goalId: goalId,
                                  uid: uid,
                                  confirmedById: currentUser!.uid,
                                );
                          },
                        )
                      : isMe
                      ? const Icon(Icons.edit, color: Colors.blue)
                      : confirmed
                      ? const Icon(Icons.check_circle, color: Colors.green)
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
