import 'package:flutter/material.dart';

import '../models/goal_model.dart';
import '../services/goal_service.dart';
import 'create_goal_screen.dart';
import 'goal_members_screen.dart';

class GoalsScreen extends StatelessWidget {
  final String gubId;

  const GoalsScreen({super.key, required this.gubId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Shared Budget")),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("New Shared Budget"),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreateGoalScreen(gubId: gubId)),
          );
        },
      ),
      body: StreamBuilder<List<GoalModel>>(
        stream: GoalService.instance.goalsStream(gubId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Unable to load Shared Budgets."));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final goals = snapshot.data!;
          final activeBudgets = goals
              .where((goal) => !goal.isCompleted)
              .toList(growable: false);
          final completedBudgets = goals
              .where((goal) => goal.isCompleted)
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
            children: [
              _sectionTitle(
                icon: Icons.account_balance_wallet_outlined,
                title: "Active Shared Budgets",
              ),
              const SizedBox(height: 12),
              if (activeBudgets.isEmpty)
                _emptySection("No active Shared Budgets.")
              else
                for (final goal in activeBudgets) _budgetCard(context, goal),
              const SizedBox(height: 28),
              _sectionTitle(
                icon: Icons.check_circle_outline_rounded,
                title: "Completed Shared Budgets",
              ),
              const SizedBox(height: 12),
              if (completedBudgets.isEmpty)
                _emptySection("No completed Shared Budgets.")
              else
                for (final goal in completedBudgets) _budgetCard(context, goal),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
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

  Widget _budgetCard(BuildContext context, GoalModel goal) {
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
