import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../models/shared_budget_model.dart';
import '../services/shared_budget_member_service.dart';
import '../services/shared_budget_service.dart';
import 'my_contribution_screen.dart';

class SharedBudgetMembersScreen extends StatefulWidget {
  final String gubId;
  final String sharedBudgetId;
  final String ownerId;

  const SharedBudgetMembersScreen({
    super.key,
    required this.gubId,
    required this.sharedBudgetId,
    required this.ownerId,
  });

  @override
  State<SharedBudgetMembersScreen> createState() =>
      _SharedBudgetMembersScreenState();
}

class _SharedBudgetMembersScreenState extends State<SharedBudgetMembersScreen> {
  final Set<String> _confirmingMemberIds = {};

  Future<void> _confirmContribution({
    required String uid,
    required String memberName,
    required double amount,
    required String confirmedById,
  }) async {
    if (_confirmingMemberIds.contains(uid)) return;

    final shouldConfirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Confirm contribution?"),
        content: Text(
          "Confirm $memberName’s contribution of "
          "€${amount.toStringAsFixed(2)}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (shouldConfirm != true || !mounted) return;

    setState(() => _confirmingMemberIds.add(uid));

    try {
      await SharedBudgetMemberService.instance.confirmContribution(
        gubId: widget.gubId,
        sharedBudgetId: widget.sharedBudgetId,
        uid: uid,
        confirmedById: confirmedById,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _confirmingMemberIds.remove(uid));
      }
    }
  }

  String _errorMessage(Object error) {
    return error
        .toString()
        .replaceFirst("Bad state: ", "")
        .replaceFirst("Invalid argument(s): ", "");
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser != null && currentUser.uid == widget.ownerId;

    return GubScreenBackground(
      variant: GubBackgroundAssignments.sharedBudget,
      whiteOverlayOpacity: GubBackgroundAssignments.economicWhiteOverlayOpacity,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Participants"),
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

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: SharedBudgetMemberService.instance.membersStream(
                gubId: widget.gubId,
                sharedBudgetId: widget.sharedBudgetId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No participants found."));
                }

                final members = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final data = members[index].data();
                    final uid = data["uid"] as String? ?? "";
                    final memberName = data["displayName"] as String? ?? "User";
                    final amount = (data["amount"] as num?)?.toDouble() ?? 0;
                    final confirmed = data["confirmed"] as bool? ?? false;
                    final isMe = currentUser != null && currentUser.uid == uid;
                    final isConfirming = _confirmingMemberIds.contains(uid);
                    final canConfirm =
                        isOwner &&
                        !sharedBudget.isCompleted &&
                        !sharedBudget.archived &&
                        !confirmed &&
                        amount > 0;

                    String status;
                    Color statusColor;

                    if (confirmed) {
                      status = "Confirmed";
                      statusColor = Colors.green;
                    } else if (amount > 0) {
                      status = "Waiting for confirmation";
                      statusColor = Colors.orange;
                    } else {
                      status = "Not submitted";
                      statusColor = Colors.grey;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: isMe
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MyContributionScreen(
                                      gubId: widget.gubId,
                                      sharedBudgetId: widget.sharedBudgetId,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    child: Text(
                                      memberName.isEmpty
                                          ? "U"
                                          : memberName[0].toUpperCase(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          memberName,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Contribution: "
                                          "€${amount.toStringAsFixed(2)}",
                                        ),
                                        if (!confirmed) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            status,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (isMe && !confirmed)
                                    const Icon(Icons.edit, color: Colors.blue),
                                ],
                              ),
                              if (confirmed) ...[
                                const SizedBox(height: 12),
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.green,
                                      size: 21,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      "Confirmed",
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (canConfirm) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FilledButton.icon(
                                    onPressed: isConfirming
                                        ? null
                                        : () => _confirmContribution(
                                            uid: uid,
                                            memberName: memberName,
                                            amount: amount,
                                            confirmedById: widget.ownerId,
                                          ),
                                    icon: isConfirming
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.check_circle_outline_rounded,
                                          ),
                                    label: const Text("Confirm contribution"),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
