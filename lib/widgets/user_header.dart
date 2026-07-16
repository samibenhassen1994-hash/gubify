import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../modules/notifications/screens/notifications_screen.dart';
import '../repositories/user_repository.dart';

class UserHeader extends StatelessWidget {
  final String? hubId;
  final bool darkMode;

  const UserHeader({super.key, this.hubId, this.darkMode = false});

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
                    color: darkMode ? Colors.white : Colors.black87,
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
                      final data = doc.data();

                      final readBy = List<String>.from(data["readBy"] ?? []);

                      final senderId = data["senderId"] ?? "";

                      final type = data["type"] ?? "";

                      if (readBy.contains(user.uid)) {
                        return false;
                      }

                      if (type == "proposal_approved" ||
                          type == "proposal_rejected") {
                        return true;
                      }

                      return senderId != user.uid;
                    }).length;

                    return SizedBox(
                      width: 56,
                      height: 56,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    NotificationsScreen(hubId: hubId!),
                              ),
                            );
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.notifications_outlined,
                                size: 28,
                                color: darkMode
                                    ? Colors.white70
                                    : Colors.black54,
                              ),

                              if (count > 0)
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: IgnorePointer(
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
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
                          ),
                        ),
                      ),
                    );
                  },
                ),

              IconButton(
                onPressed: () {
                  // TODO: Settings
                },
                icon: Icon(
                  Icons.settings_outlined,
                  color: darkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
