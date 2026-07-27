import 'package:flutter/material.dart';

import '../manage_gub_screen.dart';

class ManageGubButton extends StatelessWidget {
  final String gubId;

  const ManageGubButton({super.key, required this.gubId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          side: const BorderSide(color: Color(0xFFDCE6F5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 1,
          shadowColor: const Color(0x1A0F172A),
        ),
        icon: const Icon(Icons.settings),
        label: const Text("Manage Gub"),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ManageGubScreen(gubId: gubId)),
          );
        },
      ),
    );
  }
}
