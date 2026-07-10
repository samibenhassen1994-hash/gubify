import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../modules/notifications/screens/notifications_screen.dart';
import '../repositories/user_repository.dart';

class UserHeader extends StatelessWidget {
  final String? hubId;
  final bool darkMode;

  const UserHeader({
    super.key,
    this.hubId,
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
            child: SizedBox(height: 40),
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
                    ? Colors.white.withOpacity(.12)
                    : Colors.blue.shade100,
                child: Icon(
                  Icons.person,
                  color: darkMode ? Colors.white : Colors.blue,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: darkMode
                        ? Colors.white
                        : Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              if (hubId != null)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection("hubs")
                      .doc(hubId)
                      .collection("notifications")
                      .snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];

final count = docs.where((doc) {
  final readBy = List<String>.from(
    doc.data()["readBy"] ?? [],
  );

  return !readBy.contains(user.uid);
}).length;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.notifications_outlined,
                            color: darkMode
                                ? Colors.white70
                                : Colors.black54,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NotificationsScreen(
                                  hubId: hubId!,
                                ),
                              ),
                            );
                          },
                        ),

                        if (count > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  count > 9 ? "9+" : "$count",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),

              IconButton(
                onPressed: () {
                  // TODO: Settings
                },
                icon: Icon(
                  Icons.settings_outlined,
                  color: darkMode
                      ? Colors.white70
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