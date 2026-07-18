import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/goal_model.dart';
import '../screens/goal_members_screen.dart';
import '../services/goal_service.dart';
import 'goal_empty_card.dart';
import 'goal_progress_card.dart';

class GoalHomeCard extends StatelessWidget {
  final String gubId;
  final String ownerId;

  const GoalHomeCard({super.key, required this.gubId, required this.ownerId});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser != null && currentUser.uid == ownerId;

    return StreamBuilder<GoalModel?>(
      stream: GoalService.instance.activeGoalStream(gubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final goal = snapshot.data;

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: goal == null
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GoalMembersScreen(
                        gubId: gubId,
                        goalId: goal.goalId,
                        ownerId: ownerId,
                      ),
                    ),
                  );
                },
          child: Card(
            elevation: 3,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        "Shared Budget",
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  if (goal == null)
                    GoalEmptyCard(isOwner: isOwner, gubId: gubId)
                  else
                    GoalProgressCard(goal: goal),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
