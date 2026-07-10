import 'package:flutter/material.dart';

import '../screens/create_goal_screen.dart';

class GoalEmptyCard extends StatelessWidget {
  final bool isOwner;
  final String hubId;

  const GoalEmptyCard({
    super.key,
    required this.isOwner,
    required this.hubId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.account_balance_wallet_outlined,
          size: 60,
          color: Colors.grey,
        ),

        const SizedBox(height: 15),

        const Text(
          "No Shared Budget yet",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          "Create the first Shared Budget for this Hub.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
          ),
        ),

        if (isOwner) ...[
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Create Budget"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateGoalScreen(
                      hubId: hubId,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}