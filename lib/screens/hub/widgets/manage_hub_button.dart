import 'package:flutter/material.dart';

import '../manage_hub_screen.dart';

class ManageHubButton extends StatelessWidget {
  final String hubId;

  const ManageHubButton({
    super.key,
    required this.hubId,
  });

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
            MaterialPageRoute(
              builder: (_) => ManageHubScreen(
                hubId: hubId,
              ),
            ),
          );
        },
      ),
    );
  }
}