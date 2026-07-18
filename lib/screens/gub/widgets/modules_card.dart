import 'package:flutter/material.dart';

import '../modules_screen.dart';

class ModulesCard extends StatelessWidget {
  final String gubId;
  final List<String> activeModules;

  const ModulesCard({
    super.key,
    required this.gubId,
    required this.activeModules,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.extension),
        title: const Text("Active Modules"),
        subtitle: Text(
          activeModules.isEmpty
              ? "No modules selected"
              : activeModules.join(", "),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ModulesScreen(gubId: gubId)),
          );
        },
      ),
    );
  }
}
