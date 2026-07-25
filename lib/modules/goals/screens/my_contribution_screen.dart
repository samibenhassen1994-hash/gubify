import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../../../core/formatters/monetary_amount_input_formatter.dart';
import '../models/goal_model.dart';
import '../services/goal_member_service.dart';
import '../services/goal_service.dart';

class MyContributionScreen extends StatefulWidget {
  final String gubId;
  final String goalId;

  const MyContributionScreen({
    super.key,
    required this.gubId,
    required this.goalId,
  });

  @override
  State<MyContributionScreen> createState() => _MyContributionScreenState();
}

class _MyContributionScreenState extends State<MyContributionScreen> {
  final _amountController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit(GoalModel goal) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final normalizedValue = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(normalizedValue);
    final remainingAmount = (goal.targetAmount - goal.currentAmount)
        .clamp(0.0, double.infinity)
        .toDouble();

    if (goal.isCompleted || goal.archived || remainingAmount <= 0) {
      _showMessage("This Shared Budget is already completed.");
      return;
    }

    if (amount == null || !amount.isFinite || amount <= 0) {
      _showMessage("Enter a valid amount.");
      return;
    }

    if (amount > remainingAmount) {
      _showMessage(
        "You can contribute up to €${remainingAmount.toStringAsFixed(2)}.",
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await GoalMemberService.instance.submitContribution(
        gubId: widget.gubId,
        goalId: widget.goalId,
        uid: user.uid,
        amount: amount,
      );

      if (!mounted) return;

      _showMessage("Contribution submitted.");
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorMessage(Object error) {
    return error
        .toString()
        .replaceFirst("Bad state: ", "")
        .replaceFirst("Invalid argument(s): ", "");
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return GubScreenBackground(
      variant: GubBackgroundAssignments.sharedBudget,
      whiteOverlayOpacity: GubBackgroundAssignments.economicWhiteOverlayOpacity,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("My Contribution"),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: StreamBuilder<GoalModel?>(
          stream: GoalService.instance.goalStream(
            gubId: widget.gubId,
            goalId: widget.goalId,
          ),
          builder: (context, goalSnapshot) {
            if (goalSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final goal = goalSnapshot.data;

            if (goal == null) {
              return const Center(
                child: Text("This Shared Budget is no longer available."),
              );
            }

            if (user == null) {
              return const Center(child: Text("You must be signed in."));
            }

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: GoalMemberService.instance.memberStream(
                gubId: widget.gubId,
                goalId: widget.goalId,
                uid: user.uid,
              ),
              builder: (context, memberSnapshot) {
                if (memberSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final memberData = memberSnapshot.data?.data();

                if (memberData == null) {
                  return const Center(child: Text("Member not found."));
                }

                final contributionConfirmed =
                    memberData["confirmed"] as bool? ?? false;
                final remainingAmount = (goal.targetAmount - goal.currentAmount)
                    .clamp(0.0, double.infinity)
                    .toDouble();
                final budgetCompleted =
                    goal.isCompleted || goal.archived || remainingAmount <= 0;
                final canSubmit =
                    !budgetCompleted && !contributionConfirmed && !_loading;

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Remaining: €${remainingAmount.toStringAsFixed(2)}",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      if (budgetCompleted) ...[
                        const Text(
                          "This Shared Budget is already completed.",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _amountController,
                        enabled:
                            !budgetCompleted &&
                            !contributionConfirmed &&
                            !_loading,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: const [MonetaryAmountInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: "Contribution",
                          prefixText: "€ ",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 30),
                      if (!budgetCompleted)
                        SizedBox(
                          height: 55,
                          child: FilledButton(
                            onPressed: canSubmit ? () => _submit(goal) : null,
                            child: _loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text("Submit Contribution"),
                          ),
                        ),
                    ],
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
