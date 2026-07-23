import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../modules/goals/screens/goals_screen.dart';
import '../../modules/proposals/screens/proposals_screen.dart';
import '../../modules/gub_calendar/screens/gub_calendar_screen.dart';

class ModulesScreen extends StatelessWidget {
  final String gubId;

  const ModulesScreen({super.key, required this.gubId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Active Modules")),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection("gubs").doc(gubId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Hub not found."));
          }

          final hub = snapshot.data!.data() as Map<String, dynamic>;

          final modules = Map<String, dynamic>.from(hub["modules"] ?? {});

          final int memberCount = hub["memberCount"] ?? 1;
          final String ownerId = hub["ownerId"] ?? "";
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          final canCreateBudget =
              currentUserId != null && currentUserId == ownerId;

          final activeModules = modules.entries
              .where((e) => e.value == true)
              .toList();

          if (activeModules.isEmpty) {
            return const Center(child: Text("No active modules."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activeModules.length,
            itemBuilder: (context, index) {
              final module = activeModules[index];

              IconData icon = Icons.extension;

              switch (module.key) {
                case "goals":
                  icon = Icons.flag;
                  break;

                case "proposals":
                  icon = Icons.how_to_vote;
                  break;

                case "calendar":
                  icon = Icons.calendar_month;
                  break;

                default:
                  icon = Icons.extension;
              }

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  leading: Icon(icon, color: Colors.blue),
                  title: Text(
                    module.key == "goals"
                        ? "Shared Budget"
                        : module.key[0].toUpperCase() + module.key.substring(1),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    switch (module.key) {
                      case "goals":
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GoalsScreen(
                              gubId: gubId,
                              canCreateBudget: canCreateBudget,
                            ),
                          ),
                        );
                        break;

                      case "proposals":
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProposalsScreen(
                              gubId: gubId,
                              memberCount: memberCount,
                            ),
                          ),
                        );
                        break;
                      case "calendar":
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GubCalendarScreen(
                              gubId: gubId,
                              ownerId: ownerId,
                            ),
                          ),
                        );
                        break;
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
