import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../../../core/formatters/monetary_amount_input_formatter.dart';
import '../models/shared_budget_model.dart';
import '../services/shared_budget_member_service.dart';
import '../services/shared_budget_service.dart';

class MyContributionScreen extends StatefulWidget {
  final String gubId;
  final String sharedBudgetId;

  const MyContributionScreen({
    super.key,
    required this.gubId,
    required this.sharedBudgetId,
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

  Future<void> _submit(SharedBudgetModel sharedBudget) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final normalizedValue = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(normalizedValue);
    final remainingAmount =
        (sharedBudget.targetAmount - sharedBudget.currentAmount)
            .clamp(0.0, double.infinity)
            .toDouble();

    if (sharedBudget.isCompleted ||
        sharedBudget.archived ||
        remainingAmount <= 0) {
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
      await SharedBudgetMemberService.instance.submitContribution(
        gubId: widget.gubId,
        sharedBudgetId: widget.sharedBudgetId,
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
        body: StreamBuilder<SharedBudgetModel?>(
          stream: SharedBudgetService.instance.sharedBudgetStream(
            gubId: widget.gubId,
            sharedBudgetId: widget.sharedBudgetId,
          ),
          builder: (context, sharedBudgetSnapshot) {
            if (sharedBudgetSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final sharedBudget = sharedBudgetSnapshot.data;

            if (sharedBudget == null) {
              return const Center(
                child: Text("This Shared Budget is no longer available."),
              );
            }

            if (user == null) {
              return const Center(child: Text("You must be signed in."));
            }

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: SharedBudgetMemberService.instance.memberStream(
                gubId: widget.gubId,
                sharedBudgetId: widget.sharedBudgetId,
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
                final remainingAmount =
                    (sharedBudget.targetAmount - sharedBudget.currentAmount)
                        .clamp(0.0, double.infinity)
                        .toDouble();
                final budgetCompleted =
                    sharedBudget.isCompleted ||
                    sharedBudget.archived ||
                    remainingAmount <= 0;
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
                            onPressed: canSubmit
                                ? () => _submit(sharedBudget)
                                : null,
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
