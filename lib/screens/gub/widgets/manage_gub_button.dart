import 'package:flutter/material.dart';

import '../manage_gub_screen.dart';

class ManageGubButton extends StatelessWidget {
  final String hubId;

  const ManageGubButton({super.key, required this.hubId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.settings),
        label: const Text("Manage Hub"),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ManageGubScreen(hubId: hubId)),
          );
        },
      ),
    );
  }
}
