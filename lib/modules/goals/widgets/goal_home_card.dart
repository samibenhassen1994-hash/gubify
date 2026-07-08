import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GoalHomeCard extends StatelessWidget {
  final String hubId;
  final String ownerId;

  const GoalHomeCard({
    super.key,
    required this.hubId,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    final bool isOwner =
        currentUser != null && currentUser.uid == ownerId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.flag,
                  color: Colors.orange,
                ),
                SizedBox(width: 8),
                Text(
                  "Group Goal",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 56,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "No group goal yet",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Create the first shared goal for this Hub.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            if (isOwner) ...[
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Create Goal"),
                  onPressed: () {
                    // TODO: Aprirà CreateGoalScreen
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}