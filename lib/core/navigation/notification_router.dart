import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../modules/gub_calendar/screens/hub_calendar_screen.dart';

import '../../modules/proposals/repositories/proposal_repository.dart';
import '../../modules/proposals/screens/proposal_details_screen.dart';

import '../../modules/tasks/screens/task_details_screen.dart';

class NotificationRouter {
  NotificationRouter._();

  static Future<void> navigate({
    required BuildContext context,
    required String hubId,
    required Map<String, dynamic> data,
  }) async {
    final destination = data["module"] ?? data["screen"];

    switch (destination) {
      case "proposal":
        final proposalId = data["proposalId"];

        if (proposalId == null) return;

        final proposal =
            await ProposalRepository.instance.getProposal(
          hubId: hubId,
          proposalId: proposalId,
        );

        if (!context.mounted || proposal == null) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProposalDetailsScreen(
              proposal: proposal,
            ),
          ),
        );

        break;


      case "calendar":
        final hubDoc = await FirebaseFirestore.instance
            .collection("gubs")
            .doc(hubId)
            .get();

        if (!hubDoc.exists || !context.mounted) return;

        final ownerId =
            hubDoc.data()?["ownerId"] ?? "";

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GubCalendarScreen(
              hubId: hubId,
              ownerId: ownerId,
            ),
          ),
        );

        break;


      case "tasks":
        final taskId = data["taskId"];

        if (taskId == null) return;

        if (!context.mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskDetailsScreen(
              hubId: hubId,
              taskId: taskId,
            ),
          ),
        );

        break;


      default:
        return;
    }
  }
}