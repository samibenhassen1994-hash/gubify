import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/goal_model.dart';
import '../services/goal_service.dart';
import '../widgets/delete_goal_dialog.dart';
import 'create_goal_screen.dart';
import 'goal_members_screen.dart';

enum SharedBudgetInitialTab { active, archive }

class GoalsScreen extends StatelessWidget {
  final String gubId;
  final SharedBudgetInitialTab initialTab;
  final bool canCreateBudget;

  const GoalsScreen({
    super.key,
    required this.gubId,
    this.initialTab = SharedBudgetInitialTab.active,
    this.canCreateBudget = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final initialIndex = initialTab == SharedBudgetInitialTab.archive ? 1 : 0;

    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Shared Budget"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Active"),
              Tab(text: "Archive"),
            ],
          ),
        ),
        floatingActionButton: canCreateBudget
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: const Text("New Shared Budget"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateGoalScreen(gubId: gubId),
                    ),
                  );
                },
              )
            : null,
        body: StreamBuilder<List<GoalModel>>(
          stream: GoalService.instance.goalsStream(gubId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text("Unable to load Shared Budgets."),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final goals = snapshot.data!;
            final activeBudgets = goals
                .where((goal) => !goal.isCompleted)
                .toList(growable: false);
            final archivedBudgets = goals
                .where((goal) => goal.isCompleted)
                .toList(growable: false);

            return TabBarView(
              children: [
                _budgetList(
                  context: context,
                  budgets: activeBudgets,
                  emptyMessage: "No active Shared Budgets.",
                  currentUserId: currentUserId,
                  allowDelete: true,
                ),
                _budgetList(
                  context: context,
                  budgets: archivedBudgets,
                  emptyMessage: "No archived Shared Budgets.",
                  currentUserId: currentUserId,
                  allowDelete: false,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _budgetList({
    required BuildContext context,
    required List<GoalModel> budgets,
    required String emptyMessage,
    required String? currentUserId,
    required bool allowDelete,
  }) {
    if (budgets.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        children: [_emptySection(emptyMessage)],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
      children: [
        for (final goal in budgets)
          _budgetCard(
            context,
            goal,
            canDelete:
                allowDelete &&
                currentUserId != null &&
                currentUserId == goal.ownerId &&
                !goal.isCompleted,
          ),
      ],
    );
  }

  Widget _emptySection(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade700),
      ),
    );
  }

  Widget _budgetCard(
    BuildContext context,
    GoalModel goal, {
    required bool canDelete,
  }) {
    final calculatedProgress = goal.targetAmount <= 0
        ? 0.0
        : (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
    final progress = goal.isCompleted ? 1.0 : calculatedProgress;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GoalMembersScreen(
                gubId: gubId,
                goalId: goal.goalId,
                ownerId: goal.ownerId,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (goal.isCompleted) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Completed",
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (canDelete) ...[
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      tooltip: "Shared Budget actions",
                      onSelected: (value) {
                        if (value == "delete") {
                          showDeleteGoalDialog(
                            context: context,
                            gubId: gubId,
                            goalId: goal.goalId,
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
                    ),
                  ],
                ],
              ),
              if (goal.description.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  goal.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                "€${goal.currentAmount.toStringAsFixed(2)} of "
                "€${goal.targetAmount.toStringAsFixed(2)}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  backgroundColor: Colors.grey.shade200,
                  color: goal.isCompleted ? Colors.green : Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
