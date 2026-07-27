import 'package:flutter/material.dart';

import '../../services/gub_service.dart';
import '../../widgets/gub_content_card.dart';
import '../../widgets/gub_screen_background.dart';
import '../welcome_screen.dart';

class ManageGubScreen extends StatelessWidget {
  final String gubId;

  const ManageGubScreen({super.key, required this.gubId});

  Future<void> _deleteHub(BuildContext context) async {
    try {
      await GubService().deleteHub(gubId: gubId);

      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gub deleted successfully.")),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Hub", "Gub"))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.tasks,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Manage Gub"),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              "General",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            GubContentCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.edit),
                title: const Text("Rename Gub"),
                subtitle: const Text("Coming soon"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: null,
              ),
            ),

            const SizedBox(height: 10),

            GubContentCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.extension),
                title: const Text("Manage Modules"),
                subtitle: const Text("Coming soon"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: null,
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "Danger Zone",
              style: TextStyle(
                color: Colors.red,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            GubContentCard(
              padding: EdgeInsets.zero,
              color: const Color(0xFFFFF1F2),
              border: Border.all(color: const Color(0xFFFECACA)),
              child: ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  "Delete Gub",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text("Permanently delete this Gub."),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) {
                      return AlertDialog(
                        title: const Text("Delete Gub"),
                        content: const Text(
                          "Are you sure you want to permanently delete this Gub?\n\nThis action cannot be undone.",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text("Cancel"),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () async {
                              Navigator.pop(context);

                              await _deleteHub(context);
                            },
                            child: const Text("Delete"),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
