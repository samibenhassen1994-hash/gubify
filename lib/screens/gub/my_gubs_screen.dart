import 'package:flutter/material.dart';

import '../../modules/community/models/community_model.dart';
import '../../modules/community/screens/community_explorer_screen.dart';
import '../../modules/community/screens/gub_community_home_screen.dart';
import '../../modules/community/widgets/community_membership_card.dart';
import '../../modules/community/widgets/community_linked_account_gate.dart';
import '../../services/my_gubs_service.dart';
import '../../widgets/gub_access_guard.dart';
import '../../widgets/gub_content_card.dart';
import '../../widgets/gub_page_header.dart';
import '../../widgets/gub_screen_background.dart';
import '../../widgets/membership_details.dart';
import '../../widgets/membership_window_selector.dart';
import 'gub_screen.dart';

class MyGubsScreen extends StatefulWidget {
  const MyGubsScreen({super.key});

  @override
  State<MyGubsScreen> createState() => _MyGubsScreenState();
}

class _MyGubsScreenState extends State<MyGubsScreen> {
  late Stream<List<Map<String, dynamic>>> _privateGubsStream;
  late Stream<List<Map<String, dynamic>>> _deletingPrivateGubsStream;
  Stream<List<CommunityMembershipModel>>? _communitiesStream;
  late bool _isCurrentUserAnonymous;
  MembershipWindow _selectedWindow = MembershipWindow.privateGubs;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _privateGubsStream = MyGubsService.instance.privateGubsStream();
    _deletingPrivateGubsStream = MyGubsService.instance
        .deletingPrivateGubsStream();
    _isCurrentUserAnonymous = MyGubsService.instance.isCurrentUserAnonymous;
    _communitiesStream = communityMembershipsStreamForAccount(
      isCurrentUserAnonymous: _isCurrentUserAnonymous,
      load: MyGubsService.instance.communitiesStream,
    );
  }

  Future<void> _openPrivateGub(Map<String, dynamic> gub) async {
    final gubId = gub['gubId'] as String?;
    if (gubId == null || gubId.isEmpty) return;

    final isMember = await MyGubsService.instance.isCurrentUserMember(gubId);
    if (!mounted) return;
    if (!isMember) {
      await MyGubsService.instance.removeStalePrivateGubReference(gubId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are no longer a member of this Gub.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GubAccessGuard(
          gubId: gubId,
          child: GubScreen(gubId: gubId),
        ),
      ),
    );
  }

  void _resumePrivateGubDeletion(Map<String, dynamic> gub) {
    final gubId = gub['gubId'] as String?;
    if (gubId == null || gubId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => buildGubDeletionRecoveryDestination(gubId),
      ),
    );
  }

  Future<void> _openCommunity(CommunityMembershipModel membership) async {
    if (!await showCommunityLinkedAccountGate(context) || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GubCommunityHomeScreen(
          communityId: membership.community.communityId,
          initialCommunity: membership.community,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.myGubs,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const GubPageHeader(
              title: 'My Gubs',
              personalProfileEnabled: true,
              userHeaderInCard: true,
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _privateGubsStream,
                builder: (context, privateSnapshot) {
                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _deletingPrivateGubsStream,
                    builder: (context, recoverySnapshot) {
                      return StreamBuilder<List<CommunityMembershipModel>>(
                        stream: _communitiesStream,
                        builder: (context, communitySnapshot) {
                          final activeGubs = activePrivateGubsWithoutRecovery(
                            activeGubs: privateSnapshot.data ?? const [],
                            recoveryGubs: recoverySnapshot.data ?? const [],
                          );
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  14,
                                ),
                                child: MembershipWindowSelector(
                                  selectedWindow: _selectedWindow,
                                  privateCount:
                                      privateSnapshot.hasData ||
                                          recoverySnapshot.hasData
                                      ? activeGubs.length +
                                            (recoverySnapshot.data?.length ?? 0)
                                      : null,
                                  communityCount:
                                      communitySnapshot.data?.length,
                                  onSelected: (window) {
                                    setState(() => _selectedWindow = window);
                                  },
                                ),
                              ),
                              Expanded(
                                child:
                                    _selectedWindow ==
                                        MembershipWindow.privateGubs
                                    ? PrivateGubsWindow(
                                        snapshot: privateSnapshot,
                                        recoverySnapshot: recoverySnapshot,
                                        onRetry: () => setState(_reload),
                                        onOpen: _openPrivateGub,
                                        onResumeDeletion:
                                            _resumePrivateGubDeletion,
                                      )
                                    : CommunitiesWindow(
                                        snapshot: communitySnapshot,
                                        isCurrentUserAnonymous:
                                            _isCurrentUserAnonymous,
                                        onRetry: () => setState(_reload),
                                        onExplore: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const CommunityExplorerScreen(),
                                          ),
                                        ),
                                        onOpen: _openCommunity,
                                      ),
                              ),
                            ],
                          );
                        },
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

List<Map<String, dynamic>> activePrivateGubsWithoutRecovery({
  required List<Map<String, dynamic>> activeGubs,
  required List<Map<String, dynamic>> recoveryGubs,
}) {
  final recoveryIds = recoveryGubs
      .map((gub) => gub['gubId'])
      .whereType<String>()
      .toSet();
  return activeGubs
      .where((gub) => !recoveryIds.contains(gub['gubId']))
      .toList(growable: false);
}

Widget buildGubDeletionRecoveryDestination(String gubId) =>
    GubScreen(gubId: gubId);

class PrivateGubsWindow extends StatelessWidget {
  final AsyncSnapshot<List<Map<String, dynamic>>> snapshot;
  final AsyncSnapshot<List<Map<String, dynamic>>> recoverySnapshot;
  final VoidCallback onRetry;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final ValueChanged<Map<String, dynamic>> onResumeDeletion;

  const PrivateGubsWindow({
    super.key,
    required this.snapshot,
    required this.recoverySnapshot,
    required this.onRetry,
    required this.onOpen,
    required this.onResumeDeletion,
  });

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        recoverySnapshot.connectionState == ConnectionState.waiting) {
      return const _SectionLoading();
    }
    if (snapshot.hasError || recoverySnapshot.hasError) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [_SectionError(onRetry: onRetry)],
      );
    }

    final recoveryGubs = recoverySnapshot.data ?? const [];
    final activeGubs = activePrivateGubsWithoutRecovery(
      activeGubs: snapshot.data ?? const [],
      recoveryGubs: recoveryGubs,
    );
    if (activeGubs.isEmpty && recoveryGubs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: const [_PrivateGubsEmptyState()],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: recoveryGubs.length + activeGubs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index < recoveryGubs.length) {
          final gub = recoveryGubs[index];
          return _GubDeletionRecoveryCard(
            gub: gub,
            onTap: () => onResumeDeletion(gub),
          );
        }
        final gub = activeGubs[index - recoveryGubs.length];
        return _PrivateGubCard(gub: gub, onTap: () => onOpen(gub));
      },
    );
  }
}

class _GubDeletionRecoveryCard extends StatelessWidget {
  final Map<String, dynamic> gub;
  final VoidCallback onTap;

  const _GubDeletionRecoveryCard({required this.gub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = gub['name'] as String? ?? 'Gub';
    return GubContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deletion in progress — $name',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Resume deletion'),
          ),
        ],
      ),
    );
  }
}

class CommunitiesWindow extends StatelessWidget {
  final AsyncSnapshot<List<CommunityMembershipModel>> snapshot;
  final bool isCurrentUserAnonymous;
  final VoidCallback onRetry;
  final VoidCallback onExplore;
  final ValueChanged<CommunityMembershipModel> onOpen;

  const CommunitiesWindow({
    super.key,
    required this.snapshot,
    this.isCurrentUserAnonymous = false,
    required this.onRetry,
    required this.onExplore,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (isCurrentUserAnonymous) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: const [_AnonymousCommunitiesState()],
      );
    }
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const _SectionLoading();
    }
    if (snapshot.hasError) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [_SectionError(onRetry: onRetry)],
      );
    }

    final communities = snapshot.data ?? const [];
    if (communities.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [_CommunitiesEmptyState(onExplore: onExplore)],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: communities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final membership = communities[index];
        return CommunityMembershipCard(
          membership: membership,
          onTap: () => onOpen(membership),
        );
      },
    );
  }
}

Stream<List<CommunityMembershipModel>>? communityMembershipsStreamForAccount({
  required bool isCurrentUserAnonymous,
  required Stream<List<CommunityMembershipModel>> Function() load,
}) => isCurrentUserAnonymous ? null : load();

class _AnonymousCommunitiesState extends StatelessWidget {
  const _AnonymousCommunitiesState();

  @override
  Widget build(BuildContext context) => const GubContentCard(
    child: Column(
      children: [
        Text(
          'Communities require a connected account',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          'Connect your account to discover, join, and participate in Communities.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.black54),
        ),
      ],
    ),
  );
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _SectionError extends StatelessWidget {
  final VoidCallback onRetry;

  const _SectionError({required this.onRetry});

  @override
  Widget build(BuildContext context) => GubContentCard(
    child: Column(
      children: [
        const Text('Unable to load this section.'),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

class _PrivateGubsEmptyState extends StatelessWidget {
  const _PrivateGubsEmptyState();

  @override
  Widget build(BuildContext context) => const GubContentCard(
    child: Text(
      "You haven't joined any private Gubs yet.",
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 16, color: Colors.black54),
    ),
  );
}

class _CommunitiesEmptyState extends StatelessWidget {
  final VoidCallback onExplore;

  const _CommunitiesEmptyState({required this.onExplore});

  @override
  Widget build(BuildContext context) => GubContentCard(
    child: Column(
      children: [
        const Text(
          'You have not joined any communities yet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onExplore,
          icon: const Icon(Icons.public_rounded),
          label: const Text('Explore Communities'),
        ),
      ],
    ),
  );
}

class _PrivateGubCard extends StatelessWidget {
  final Map<String, dynamic> gub;
  final VoidCallback onTap;

  const _PrivateGubCard({required this.gub, required this.onTap});

  @override
  Widget build(BuildContext context) => GubContentCard(
    padding: EdgeInsets.zero,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFF2563EB).withValues(alpha: .12),
        child: const Icon(Icons.hub_outlined, color: Color(0xFF2563EB)),
      ),
      title: Text(
        gub['name'] as String? ?? 'Gub',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: MembershipDetails(
          role: gub['isFounder'] == true
              ? 'Founder'
              : formatRoleLabel(gub['role'] as String?, fallback: 'Member'),
          joinedAt: gub['joinedAtDate'] as DateTime?,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 22),
      onTap: onTap,
    ),
  );
}
