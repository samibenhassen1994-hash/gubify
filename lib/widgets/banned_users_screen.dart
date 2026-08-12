import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'gub_content_card.dart';
import 'gub_screen_background.dart';

class BannedUsersScreen extends StatelessWidget {
  final String title;
  final Stream<List<Map<String, dynamic>>> bannedUsersStream;
  final Future<void> Function(String uid) onUnban;

  const BannedUsersScreen({
    super.key,
    required this.title,
    required this.bannedUsersStream,
    required this.onUnban,
  });

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.profiles,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: bannedUsersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Unable to load banned users.'),
                );
              }
              final users = snapshot.data ?? const <Map<String, dynamic>>[];
              if (users.isEmpty) {
                return const Center(child: Text('No banned users.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                itemCount: users.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final uid =
                      user['userId'] as String? ?? user['uid'] as String? ?? '';
                  final displayName = user['displayName'] as String?;
                  final name = displayName?.trim().isNotEmpty == true
                      ? displayName!.trim()
                      : 'User';
                  final bannedAt = user['bannedAt'] ?? user['createdAt'];
                  final subtitle = bannedAt is Timestamp
                      ? 'Banned ${MaterialLocalizations.of(context).formatShortDate(bannedAt.toDate())}'
                      : 'Banned user';
                  return GubContentCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleAvatar(child: Text(name[0].toUpperCase())),
                      title: Text(name),
                      subtitle: Text(subtitle),
                      trailing: uid.isEmpty
                          ? null
                          : TextButton(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Unban user?'),
                                    content: const Text(
                                      'This user will be able to join or request access again.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Unban'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true || !context.mounted) {
                                  return;
                                }
                                try {
                                  await onUnban(uid);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Unable to unban user.'),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('Unban'),
                            ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
