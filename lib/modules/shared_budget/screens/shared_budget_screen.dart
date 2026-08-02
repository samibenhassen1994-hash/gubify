import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/models/creation_availability.dart';
import '../../../core/navigation/creation_gate.dart';
import '../../../widgets/gub_content_card.dart';
import '../../../widgets/gub_screen_background.dart';
import '../../chat/widgets/gub_chat_overlay.dart';
import '../models/shared_budget_model.dart';
import '../services/shared_budget_service.dart';
import '../widgets/delete_shared_budget_dialog.dart';
import 'create_shared_budget_screen.dart';
import 'shared_budget_members_screen.dart';

enum SharedBudgetInitialTab { active, archive }

class SharedBudgetScreen extends StatelessWidget {
  final String gubId;
  final SharedBudgetInitialTab initialTab;
  final bool canCreateBudget;

  const SharedBudgetScreen({
    super.key,
    required this.gubId,
    this.initialTab = SharedBudgetInitialTab.active,
    this.canCreateBudget = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final initialIndex = initialTab == SharedBudgetInitialTab.archive ? 1 : 0;

    return ChatFloatingActionButtonRouteScope(
      additionalBottomOffset: canCreateBudget ? kFloatingActionButtonMargin : 0,
      child: GubScreenBackground(
        variant: GubBackgroundAssignments.sharedBudget,
        whiteOverlayOpacity:
            GubBackgroundAssignments.economicWhiteOverlayOpacity,
        child: DefaultTabController(
          length: 2,
          initialIndex: initialIndex,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text("Shared Budget"),
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
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
                          builder: (_) =>
                              CreateSharedBudgetScreen(gubId: gubId),
                        ),
                      );
                    },
                  )
                : null,
            body: StreamBuilder<List<SharedBudgetModel>>(
              stream: SharedBudgetService.instance.sharedBudgetsStream(gubId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text("Unable to load Shared Budgets."),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sharedBudgets = snapshot.data!;
                final activeBudgets = sharedBudgets
                    .where((sharedBudget) => !sharedBudget.isCompleted)
                    .toList(growable: false);
                final archivedBudgets = sharedBudgets
                    .where((sharedBudget) => sharedBudget.isCompleted)
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
        ),
      ),
    );
  }

  Widget _budgetList({
    required BuildContext context,
    required List<SharedBudgetModel> budgets,
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
        for (final sharedBudget in budgets)
          _budgetCard(
            context,
            sharedBudget,
            canDelete:
                allowDelete &&
                currentUserId != null &&
                currentUserId == sharedBudget.ownerId &&
                !sharedBudget.isCompleted,
          ),
      ],
    );
  }

  Widget _emptySection(String message) {
    return GubContentCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade700),
      ),
    );
  }

  Widget _budgetCard(
    BuildContext context,
    SharedBudgetModel sharedBudget, {
    required bool canDelete,
  }) {
    final calculatedProgress = sharedBudget.targetAmount <= 0
        ? 0.0
        : (sharedBudget.currentAmount / sharedBudget.targetAmount).clamp(
            0.0,
            1.0,
          );
    final progress = sharedBudget.isCompleted ? 1.0 : calculatedProgress;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SharedBudgetMembersScreen(
                gubId: gubId,
                sharedBudgetId: sharedBudget.sharedBudgetId,
                ownerId: sharedBudget.ownerId,
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
                      sharedBudget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (sharedBudget.isCompleted) ...[
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
                          showDeleteSharedBudgetDialog(
                            context: context,
                            gubId: gubId,
                            sharedBudgetId: sharedBudget.sharedBudgetId,
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
              if (sharedBudget.description.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  sharedBudget.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                "€${sharedBudget.currentAmount.toStringAsFixed(2)} of "
                "€${sharedBudget.targetAmount.toStringAsFixed(2)}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  backgroundColor: Colors.grey.shade200,
                  color: sharedBudget.isCompleted ? Colors.green : Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
