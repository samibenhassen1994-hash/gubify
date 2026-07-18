import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../repositories/gub_repository.dart';
import '../members_screen.dart';

class MembersCard extends StatelessWidget {
  final String gubId;
  final int memberCount;

  const MembersCard({
    super.key,
    required this.gubId,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: GubRepository.instance.hubStream(gubId),
        builder: (context, snapshot) {
          final liveData = snapshot.data?.data();

          final liveMemberCount = liveData?["memberCount"] ?? memberCount;

          return ListTile(
            leading: const Icon(Icons.people),
            title: const Text("Members"),
            subtitle: const Text("View all members"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  liveMemberCount.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MembersScreen(
                    gubId: gubId,
                    ownerId: liveData?["ownerId"] ?? "",
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
