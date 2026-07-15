import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/user_header.dart';
import '../../widgets/hub_home_background.dart';
import 'hub_screen.dart';
import '../../widgets/hub_access_guard.dart';
import '../../widgets/hub_page_header.dart';

class MyHubsScreen extends StatelessWidget {
  const MyHubsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      
      body: HubBackground(
        child: Column(
          children: [
            const HubPageHeader(
  title: "My Hubs",
),
            Expanded(
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection("users")
                    .doc(uid)
                    .collection("hubs")
                    .orderBy("joinedAt", descending: true)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "You haven't joined any Hub yet.",
                      ),
                    );
                  }

                  final hubs = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: hubs.length,
                    itemBuilder: (context, index) {
                      final hub =
                          hubs[index].data() as Map<String, dynamic>;

                      final hubId = hub["hubId"];

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          leading: CircleAvatar(
                            radius: 26,
                            backgroundColor:
                                Colors.blue.withValues(alpha: .12),
                            child: const Icon(
                              Icons.groups,
                              color: Colors.blue,
                            ),
                          ),
                          title: Text(
                            hub["name"] ?? "Hub",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          subtitle: const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              "Tap to open",
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 18,
                          ),
                          onTap: () async {
                            final memberDoc =
                                await FirebaseFirestore.instance
                                    .collection("hubs")
                                    .doc(hubId)
                                    .collection("members")
                                    .doc(uid)
                                    .get();

                            if (!memberDoc.exists) {
                              await FirebaseFirestore.instance
                                  .collection("users")
                                  .doc(uid)
                                  .collection("hubs")
                                  .doc(hubId)
                                  .delete();

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "You are no longer a member of this Hub.",
                                  ),
                                ),
                              );

                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const MyHubsScreen(),
                                ),
                              );

                              return;
                            }

                            if (!context.mounted) return;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HubAccessGuard(
                                  hubId: hubId,
                                  child: HubScreen(
                                    hubId: hubId,
                                  ),
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