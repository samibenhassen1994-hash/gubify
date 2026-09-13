import 'package:flutter/material.dart';

import '../../../../widgets/banned_users_screen.dart';
import '../models/community_model.dart';
import '../screens/community_members_screen.dart';
import '../screens/community_join_requests_screen.dart';
import '../services/community_service.dart';
import 'platform_admin_gate.dart';
import 'platform_admin_service.dart';
import 'platform_content_screen.dart';
import 'platform_moderation_model.dart';

class PlatformCommunityScreen extends StatelessWidget {
  const PlatformCommunityScreen({
    super.key,
    required this.community,
    required this.role,
  });
  final CommunityModel community;
  final PlatformAdminService role;
  void _open(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlatformAdminGate(service: role, builder: builder),
        ),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(community.name)),
    body: ListView(
      children: [
        const ListTile(
          title: Text('Platform moderator'),
          subtitle: Text(
            'Moderation does not join this Community or change its owner.',
          ),
        ),
        ListTile(
          title: const Text('Members'),
          trailing: const Icon(Icons.people_outline),
          onTap: () => _open(
            context,
            (_) =>
                CommunityMembersScreen(community: community, canModerate: true),
          ),
        ),
        ListTile(
          title: const Text('Join requests'),
          trailing: const Icon(Icons.person_add_outlined),
          onTap: () => _open(
            context,
            (_) => CommunityJoinRequestsScreen(
              community: community,
              confirmBeforeResolve: true,
            ),
          ),
        ),
        ListTile(
          title: const Text('Banned users'),
          trailing: const Icon(Icons.block),
          onTap: () => _open(
            context,
            (_) => BannedUsersScreen(
              title: 'Banned users',
              bannedUsersStream: CommunityService.instance.bannedUsersStream(
                community.communityId,
              ),
              onUnban: (uid) => CommunityService.instance.unbanMember(
                communityId: community.communityId,
                uid: uid,
              ),
            ),
          ),
        ),
        for (final kind in [
          PlatformContentKind.messages,
          PlatformContentKind.asks,
        ])
          ListTile(
            title: Text(
              kind == PlatformContentKind.messages ? 'Chat' : 'Ask and Answer',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(
              context,
              (_) => PlatformContentScreen(
                communityId: community.communityId,
                kind: kind,
                role: role,
              ),
            ),
          ),
      ],
    ),
  );
}
