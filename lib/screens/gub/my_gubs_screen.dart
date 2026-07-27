import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/gub_access_guard.dart';
import '../../widgets/gub_page_header.dart';
import '../../widgets/gub_screen_background.dart';
import 'gub_screen.dart';

class MyGubsScreen extends StatelessWidget {
  const MyGubsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return GubScreenBackground(
      variant: GubBackgroundAssignments.myGubs,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const GubPageHeader(
              title: "My Gubs",
              personalProfileEnabled: true,
              userHeaderInCard: true,
            ),

            Expanded(
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection("users")
                    .doc(uid)
                    .collection("gubs")
                    .orderBy("joinedAt", descending: true)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "You haven't joined any Gub yet.",
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    );
                  }

                  final hubs = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: hubs.length,
                    itemBuilder: (context, index) {
                      final hub = hubs[index].data() as Map<String, dynamic>;

                      final gubId = hub["gubId"];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          leading: CircleAvatar(
                            radius: 26,
                            backgroundColor: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: .12),
                            child: const Icon(
                              Icons.hub_outlined,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          title: Text(
                            hub["name"] ?? "Gub",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          subtitle: const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              "Open Gub",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 22,
                          ),
                          onTap: () async {
                            final memberDoc = await FirebaseFirestore.instance
                                .collection("gubs")
                                .doc(gubId)
                                .collection("members")
                                .doc(uid)
                                .get();

                            if (!memberDoc.exists) {
                              await FirebaseFirestore.instance
                                  .collection("users")
                                  .doc(uid)
                                  .collection("gubs")
                                  .doc(gubId)
                                  .delete();

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "You are no longer a member of this Gub.",
                                  ),
                                ),
                              );

                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MyGubsScreen(),
                                ),
                              );

                              return;
                            }

                            if (!context.mounted) return;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GubAccessGuard(
                                  gubId: gubId,
                                  child: GubScreen(gubId: gubId),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
