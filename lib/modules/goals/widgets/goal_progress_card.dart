import 'package:flutter/material.dart';

import '../models/goal_model.dart';

class GoalProgressCard extends StatelessWidget {
  final GoalModel goal;
  final bool compact;
  final bool showModuleLabel;
  final bool showFooterHint;

  const GoalProgressCard({
    super.key,
    required this.goal,
    this.compact = false,
    this.showModuleLabel = true,
    this.showFooterHint = true,
  });

  @override
  Widget build(BuildContext context) {
    final calculatedProgress = goal.targetAmount <= 0
        ? 0.0
        : (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
    final progress = goal.isCompleted ? 1.0 : calculatedProgress;
    final accentColor = goal.isCompleted ? Colors.green : Colors.blue;
    final percentage = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showModuleLabel) ...[
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: goal.isCompleted
                    ? Colors.green.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    goal.isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.account_balance_wallet_rounded,
                    color: accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    goal.isCompleted ? "Completed" : "Shared Budget",
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: compact ? 14 : 24),
        ],
        Text(
          goal.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 21 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (goal.description.isNotEmpty) ...[
          SizedBox(height: compact ? 5 : 8),
          Text(
            goal.description,
            textAlign: TextAlign.center,
            maxLines: compact ? 2 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: TextStyle(
              color: Colors.grey.shade600,
              height: compact ? 1.3 : 1.4,
            ),
          ),
        ],
        if (goal.deadline != null) ...[
          SizedBox(height: compact ? 11 : 18),
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 11 : 14,
                vertical: compact ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: compact ? 16 : 18,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "${goal.deadline!.toDate().day}/"
                    "${goal.deadline!.toDate().month}/"
                    "${goal.deadline!.toDate().year}",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
        SizedBox(height: compact ? 17 : 28),
        Center(
          child: Text(
            "$percentage%",
            style: TextStyle(
              fontSize: compact ? 34 : 42,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ),
        SizedBox(height: compact ? 3 : 6),
        Center(
          child: Text(
            goal.isCompleted ? "Completed" : "In progress",
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        SizedBox(height: compact ? 13 : 22),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: compact ? 10 : 14,
            backgroundColor: Colors.grey.shade200,
            color: accentColor,
          ),
        ),
        SizedBox(height: compact ? 15 : 24),
        Container(
          padding: EdgeInsets.all(compact ? 14 : 18),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Text(
                "€${goal.currentAmount.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: compact ? 25 : 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "of €${goal.targetAmount.toStringAsFixed(2)}",
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 13 : 20),
        Container(
          padding: EdgeInsets.all(compact ? 13 : 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue.shade100),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: compact ? 18 : 20,
                backgroundColor: Colors.blue,
                child: Icon(
                  Icons.people,
                  color: Colors.white,
                  size: compact ? 20 : 24,
                ),
              ),
              SizedBox(width: compact ? 11 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Participants",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${goal.completedMembers} of "
                      "${goal.totalMembers} confirmed",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
        if (showFooterHint) ...[
          SizedBox(height: compact ? 12 : 20),
          Center(
            child: Text(
              "Tap anywhere on this card to manage contributions",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: compact ? 12 : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
