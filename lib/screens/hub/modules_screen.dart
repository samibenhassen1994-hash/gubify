import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ModulesScreen extends StatelessWidget {
  final String hubId;

  const ModulesScreen({
    super.key,
    required this.hubId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Active Modules"),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection("hubs")
            .doc(hubId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(
              child: Text("Hub not found."),
            );
          }

          final hub =
              snapshot.data!.data() as Map<String, dynamic>;

          final modules =
              Map<String, dynamic>.from(hub["modules"] ?? {});

          final activeModules = modules.entries
              .where((e) => e.value == true)
              .toList();

          if (activeModules.isEmpty) {
            return const Center(
              child: Text("No active modules."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activeModules.length,
            itemBuilder: (context, index) {
              final module = activeModules[index];

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.extension,
                    color: Colors.blue,
                  ),
                  title: Text(
                    module.key[0].toUpperCase() +
                        module.key.substring(1),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}