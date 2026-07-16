import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../modules/goals/screens/goals_screen.dart';
import '../../modules/proposals/screens/proposals_screen.dart';
import '../../modules/hub_calendar/screens/hub_calendar_screen.dart';

class ModulesScreen extends StatelessWidget {
  final String hubId;

  const ModulesScreen({super.key, required this.hubId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Active Modules")),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection("hubs").doc(hubId).get(),
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
                    module.key[0].toUpperCase() + module.key.substring(1),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    switch (module.key) {
                      case "goals":
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GoalsScreen(hubId: hubId),
                          ),
                        );
                        break;

                      case "proposals":
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProposalsScreen(
                              hubId: hubId,
                              memberCount: memberCount,
                            ),
                          ),
                        );
                        break;
                      case "calendar":
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HubCalendarScreen(
                              hubId: hubId,
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
