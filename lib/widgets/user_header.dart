import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserHeader extends StatelessWidget {
  final bool darkMode;

  const UserHeader({
    super.key,
    this.darkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;

        final displayName = data?["displayName"] ?? "Utente";

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: darkMode
                    ? Colors.white.withValues(alpha: .12)
                    : Colors.blue.shade100,
                child: Icon(
                  Icons.person,
                  color: darkMode
                      ? Colors.white
                      : Colors.blue,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: darkMode ? Colors.white : Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.settings_outlined,
                  color: darkMode
                      ? Colors.white.withValues(alpha: .8)
                      : Colors.black54,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}