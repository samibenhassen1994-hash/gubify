import 'package:flutter/material.dart';

import '../../../core/models/creation_availability.dart';
import '../../../core/navigation/creation_gate.dart';
import '../screens/create_shared_budget_screen.dart';
import '../screens/shared_budget_screen.dart';

class SharedBudgetEmptyCard extends StatelessWidget {
  final bool isOwner;
  final String gubId;

  const SharedBudgetEmptyCard({
    super.key,
    required this.isOwner,
    required this.gubId,
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        const Text(
          "Create the first Shared Budget for this Hub.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),

        const SizedBox(height: 20),

        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            if (isOwner)
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Create Budget"),
                onPressed: () async {
                  final allowed = await CreationGate.ensureAvailable(
                    context: context,
                    gubId: gubId,
                    moduleType: CreationModuleType.sharedBudget,
                  );
                  if (!allowed || !context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateSharedBudgetScreen(gubId: gubId),
                    ),
                  );
                },
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.archive_outlined),
              label: const Text("Archive"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SharedBudgetScreen(
                      gubId: gubId,
                      initialTab: SharedBudgetInitialTab.archive,
                      canCreateBudget: isOwner,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
