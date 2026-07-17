import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../repositories/hub_repository.dart';
import '../../widgets/user_header.dart';

class InviteMembersScreen extends StatelessWidget {
  final String hubId;

  const InviteMembersScreen({super.key, required this.hubId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Invite Members")),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: HubRepository.instance.getHub(hubId),
        builder: (context, hubSnapshot) {
          if (hubSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!hubSnapshot.hasData || hubSnapshot.data == null) {
            return const Center(child: Text("Hub not found"));
          }

          final hub = hubSnapshot.data!;

          final String hubName = hub["name"] ?? "Hub";
          final String inviteCode = hub["inviteCode"] ?? "";

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const UserHeader(),

                Text(
                  hubName,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Invite people to your Hub",
                  style: TextStyle(color: Colors.grey, fontSize: 17),
                ),

                const SizedBox(height: 30),

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
                        "Hub Code",
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
                  width: double.infinity,
                  height: 55,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text("Copy Code"),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: inviteCode));

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Code copied to clipboard"),
                          ),
                        );
                      }
                    },
                  ),
                ),

                const SizedBox(height: 15),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text("Share"),
                    onPressed: () async {
                      await SharePlus.instance.share(
                        ShareParams(
                          text:
                              '🏠 Join my Hub "$hubName" on Gubify!\n\n'
                              'Download Gubify and enter this invite code:\n\n'
                              '$inviteCode',
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 35),

                const Text(
                  "Members",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 15),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("hubs")
                        .doc(hubId)
                        .collection("members")
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text("No members yet"));
                      }

                      final members = snapshot.data!.docs;

                      return ListView.builder(
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member =
                              members[index].data() as Map<String, dynamic>;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: const Icon(Icons.person),
                              ),
                              title: Text(member["displayName"] ?? "User"),
                              subtitle: Text(member["role"] ?? ""),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
