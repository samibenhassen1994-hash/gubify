import 'package:flutter/material.dart';

import '../models/community_model.dart';
import 'platform_admin_service.dart';
import 'platform_admin_gate.dart';
import 'platform_community_screen.dart';
import 'platform_moderation_service.dart';

class PlatformCommunitiesScreen extends StatefulWidget {
  const PlatformCommunitiesScreen({super.key, required this.role});
  final PlatformAdminService role;
  @override
  State<PlatformCommunitiesScreen> createState() =>
      _PlatformCommunitiesScreenState();
}

class _PlatformCommunitiesScreenState extends State<PlatformCommunitiesScreen> {
  late final service = PlatformModerationService(role: widget.role);
  int _limit = 50;
  late Stream<List<CommunityModel>> _communities = service.communities(_limit);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Community moderation')),
    body: StreamBuilder<List<CommunityModel>>(
      stream: _communities,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load communities.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final communities = snapshot.data!;
        if (communities.isEmpty) {
          return const Center(child: Text('No communities.'));
        }
        return ListView(
          children: [
            for (final community in communities)
              ListTile(
                title: Text(community.name),
                subtitle: Text(
                  '${community.accessMode} · ${community.memberCount} members',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: community.deletionStatus == 'deleting'
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PlatformAdminGate(
                            service: widget.role,
                            builder: (_) => PlatformCommunityScreen(
                              community: community,
                              role: widget.role,
                            ),
                          ),
                        ),
                      ),
              ),
            if (communities.length == _limit)
              TextButton(
                onPressed: () => setState(() {
                  _limit += 50;
                  _communities = service.communities(_limit);
                }),
                child: const Text('Load more'),
              ),
          ],
        );
      },
    ),
  );
}