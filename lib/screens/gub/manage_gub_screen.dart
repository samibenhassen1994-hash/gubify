import 'package:flutter/material.dart';

import '../../services/gub_service.dart';
import '../welcome_screen.dart';

class ManageGubScreen extends StatelessWidget {
  final String hubId;

  const ManageGubScreen({super.key, required this.hubId});

  Future<void> _deleteHub(BuildContext context) async {
    try {
      await GubService().deleteHub(hubId: hubId);

      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hub deleted successfully.")),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Hub")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "General",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Rename Hub"),
              subtitle: const Text("Coming soon"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: null,
            ),
          ),

          Card(
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

          Card(
            color: Colors.red.withValues(alpha: .05),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                "Delete Hub",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text("Permanently delete this Hub."),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) {
                    return AlertDialog(
                      title: const Text("Delete Hub"),
                      content: const Text(
                        "Are you sure you want to permanently delete this Hub?\n\nThis action cannot be undone.",
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
    );
  }
}
