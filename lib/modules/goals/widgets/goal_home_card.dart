import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/goal_model.dart';
import '../screens/goal_members_screen.dart';
import '../screens/goals_screen.dart';
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

    return StreamBuilder<List<GoalModel>>(
      stream: GoalService.instance.activeGoalsStream(gubId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildBudgetCard(
            child: const Center(child: Text("Unable to load Shared Budgets.")),
          );
        }

        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final activeBudgets = snapshot.data!;

        if (activeBudgets.isEmpty) {
          return _buildBudgetCard(
            child: GoalEmptyCard(isOwner: isOwner, gubId: gubId),
          );
        }

        final latestBudget = activeBudgets.first;
        final remainingCount = activeBudgets.length - 1;

        return _buildBudgetCard(
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GoalMembersScreen(
                        gubId: gubId,
                        goalId: latestBudget.goalId,
                        ownerId: ownerId,
                      ),
                    ),
                  );
                },
                child: SizedBox(
                  width: double.infinity,
                  child: GoalProgressCard(goal: latestBudget),
                ),
              ),
              if (remainingCount > 0) ...[
                const Divider(height: 32),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GoalsScreen(gubId: gubId),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.view_list_rounded,
                          size: 21,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            remainingCount == 1
                                ? "1 more active Shared Budget"
                                : "$remainingCount more active Shared Budgets",
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBudgetCard({required Widget child}) {
    return Card(
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 25),
            child,
          ],
        ),
      ),
    );
  }
}
