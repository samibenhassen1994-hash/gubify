import 'package:flutter/material.dart';

import '../../../widgets/gubify_swipe_back.dart';

import '../models/community_model.dart';
import 'platform_admin_service.dart';
import 'platform_admin_gate.dart';
import 'platform_community_screen.dart';
import 'platform_moderation_service.dart';
import 'platform_reports_screen.dart';

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
  Widget build(BuildContext context) => GubifySwipeBack(
    child: Scaffold(
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
        return ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Reports inbox'),
              subtitle: const Text(
                'Review user reports. Child-safety reports are high priority.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlatformAdminGate(
                    service: widget.role,
                    builder: (_) => PlatformReportsScreen(role: widget.role),
                  ),
                ),
              ),
            ),
            const Divider(),
            if (communities.isEmpty)
              const ListTile(title: Text('No communities.')),
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
    ),
  );
}
