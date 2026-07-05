import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class InviteMembersScreen extends StatelessWidget {
  final String hubId;

  const InviteMembersScreen({
    super.key,
    required this.hubId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Invita membri"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("hubs")
            .doc(hubId)
            .snapshots(),
        builder: (context, hubSnapshot) {
          if (hubSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!hubSnapshot.hasData || !hubSnapshot.data!.exists) {
            return const Center(
              child: Text("Hub non trovato"),
            );
          }

          final hub =
              hubSnapshot.data!.data() as Map<String, dynamic>;

          final String hubName = hub["name"] ?? "Hub";
          final String inviteCode = hub["inviteCode"] ?? "";

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  hubName,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Invita persone nel tuo Hub",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 17,
                  ),
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
                        "Codice Hub",
                        style: TextStyle(
                          color: Colors.grey,
                        ),
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
                    label: const Text("Copia codice"),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: inviteCode),
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Codice copiato negli appunti",
                            ),
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
                    label: const Text("Condividi"),
                    onPressed: () {
                      Share.share(
                        "🏠 Ti invito nel mio Hub \"$hubName\"!\n\n"
                        "Scarica Hubfy e inserisci questo codice:\n\n"
                        "$inviteCode",
                      );
                    },
                  ),
                ),

                const SizedBox(height: 35),

                const Text(
                  "Membri",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
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

                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (!snapshot.hasData ||
                          snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text("Nessun membro"),
                        );
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
                                backgroundColor:
                                    Colors.blue.shade100,
                                child: const Icon(Icons.person),
                              ),
                              title: Text(
                                member["displayName"] ?? "Utente",
                              ),
                              subtitle: Text(
                                member["role"] ?? "",
                              ),
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