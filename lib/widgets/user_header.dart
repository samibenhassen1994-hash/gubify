import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/user_repository.dart';

class UserHeader extends StatelessWidget {
  final bool darkMode;

  const UserHeader({
    super.key,
    this.darkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return FutureBuilder<Map<String, dynamic>?>(
      future: UserRepository.instance.getUser(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: SizedBox(
              height: 40,
            ),
          );
        }

        final data = snapshot.data;

        final displayName = data?["displayName"] ?? "User";

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
                  color: darkMode ? Colors.white : Colors.blue,
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