import 'package:flutter/material.dart';

import '../../repositories/hub_repository.dart';
import '../../widgets/user_header.dart';
import '../welcome_screen.dart';
import 'board_screen.dart';
import 'invite_members_screen.dart';

class HubScreen extends StatelessWidget {
  final String hubId;

  const HubScreen({
    super.key,
    required this.hubId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const WelcomeScreen(),
              ),
            );
          },
        ),
        title: const Text("Hubfy"),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: HubRepository.instance.getHub(hubId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text("Hub not found"),
            );
          }

          final data = snapshot.data!;

          final String hubName = data["name"] ?? "Hub";
          final String inviteCode = data["inviteCode"] ?? "";
          final int memberCount = data["memberCount"] ?? 1;

          final Map<String, dynamic> modules =
              Map<String, dynamic>.from(data["modules"] ?? {});

          final activeModules = modules.entries
              .where((e) => e.value == true)
              .map((e) => e.key)
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const UserHeader(),

                Text(
                  hubName,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  "Welcome to your Hub",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 30),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.campaign),
                    title: const Text("Board"),
                    subtitle: const Text(
                      "All group activities will appear here.",
                    ),
                    trailing:
                        const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BoardScreen(
                            hubId: hubId,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text("Members"),
                    trailing: Text(
                      memberCount.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.extension),
                    title: const Text("Active modules"),
                    subtitle: Text(
                      activeModules.isEmpty
                          ? "No modules selected"
                          : activeModules.join(", "),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.vpn_key),
                    title: const Text("Invite code"),
                    subtitle: Text(inviteCode),
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text("Invite members"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InviteMembersScreen(
                            hubId: hubId,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 15),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.settings),
                    label: const Text("Manage Hub"),
                    onPressed: () {},
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