import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/goal_model.dart';
import '../screens/goal_members_screen.dart';
import '../screens/goals_screen.dart';
import '../services/goal_service.dart';
import 'delete_goal_dialog.dart';
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
    final currentUserId = currentUser?.uid;

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
        final canDelete =
            currentUserId != null &&
            currentUserId == latestBudget.ownerId &&
            !latestBudget.isCompleted;

        return _buildBudgetCard(
          headerAction: canDelete
              ? PopupMenuButton<String>(
                  tooltip: "Shared Budget actions",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  onSelected: (value) {
                    if (value == "delete") {
                      showDeleteGoalDialog(
                        context: context,
                        gubId: gubId,
                        goalId: latestBudget.goalId,
                      );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: "delete",
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 10),
                          Text("Delete"),
                        ],
                      ),
                    ),
                  ],
                )
              : null,
          onArchive: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GoalsScreen(
                  gubId: gubId,
                  initialTab: SharedBudgetInitialTab.archive,
                  canCreateBudget: isOwner,
                ),
              ),
            );
          },
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
                  child: GoalProgressCard(
                    goal: latestBudget,
                    compact: true,
                    showModuleLabel: false,
                    showFooterHint: false,
                  ),
                ),
              ),
              if (remainingCount > 0) ...[
                const Divider(height: 24),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GoalsScreen(
                          gubId: gubId,
                          initialTab: SharedBudgetInitialTab.active,
                          canCreateBudget: isOwner,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
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

  Widget _buildBudgetCard({
    required Widget child,
    Widget? headerAction,
    VoidCallback? onArchive,
  }) {
    return Card(
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Shared Budget",
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                ),
                ?headerAction,
              ],
            ),
            const SizedBox(height: 14),
            child,
            if (onArchive != null) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: onArchive,
                  icon: const Icon(Icons.archive_outlined, size: 19),
                  label: const Text("Archive"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
