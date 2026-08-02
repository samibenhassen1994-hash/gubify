import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../repositories/gub_repository.dart';
import '../../services/gub_service.dart';
import '../../widgets/gub_content_card.dart';
import '../../widgets/gub_screen_background.dart';
import '../../widgets/user_header.dart';

class InviteMembersScreen extends StatelessWidget {
  final String gubId;

  const InviteMembersScreen({super.key, required this.gubId});

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.tasks,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Invite Members"),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: FutureBuilder<Map<String, dynamic>?>(
          future: GubRepository.instance.getHub(gubId),
          builder: (context, hubSnapshot) {
            if (hubSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!hubSnapshot.hasData || hubSnapshot.data == null) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: GubContentCard(
                  child: Text("Gub not found", textAlign: TextAlign.center),
                ),
              );
            }

            final hub = hubSnapshot.data!;
            final gubName = hub["name"] as String? ?? "Gub";
            final inviteCode = hub["inviteCode"] as String? ?? "";

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserHeader(gubId: gubId),
                    GubContentCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            gubName,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Invite people to your Gub",
                            style: TextStyle(color: Colors.grey, fontSize: 17),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "Gub Code",
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  inviteCode,
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 55,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.copy),
                              label: const Text("Copy Code"),
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: inviteCode),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Code copied to clipboard"),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            height: 55,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.share),
                              label: const Text("Share"),
                              onPressed: () async {
                                await SharePlus.instance.share(
                                  ShareParams(
                                    text:
                                        'Join my Gub "$gubName" on Gubify!\n\n'
                                        'Download Gubify and enter this invite code:\n\n'
                                        '$inviteCode',
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      "Members",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    StreamBuilder(
                      stream: GubService().rawMembersStream(gubId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const GubContentCard(
                            child: Text(
                              "No members yet",
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        return Column(
                          children: [
                            for (final document in snapshot.data!.docs)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  color: Colors.white,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.shade100,
                                      child: const Icon(Icons.person),
                                    ),
                                    title: Text(
                                      document.data()["displayName"] ?? "User",
                                    ),
                                    subtitle: Text(
                                      document.data()["role"] ?? "",
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
