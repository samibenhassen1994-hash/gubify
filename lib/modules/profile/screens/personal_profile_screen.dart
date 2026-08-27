import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../../../widgets/membership_details.dart';
import '../../../widgets/membership_window_selector.dart';
import '../../chat/widgets/chat_user_avatar.dart';
import '../../community/models/community_model.dart';
import '../../community/screens/gub_community_home_screen.dart';
import '../../community/widgets/community_membership_card.dart';
import '../../community/widgets/community_linked_account_gate.dart';
import '../models/user_profile_model.dart';
import '../services/user_profile_service.dart';
import '../widgets/google_account_connection_section.dart';
import 'user_profile_screen.dart';
import '../../../services/auth_service.dart';

class PersonalProfileScreen extends StatefulWidget {
  final String userId;
  final AuthService? authService;
  final Future<UserProfileModel>? profileFuture;
  final Stream<List<PersonalGubModel>>? gubsStream;
  final Stream<List<CommunityMembershipModel>>? communitiesStream;
  final Widget? accountConnectionSection;

  const PersonalProfileScreen({
    super.key,
    required this.userId,
    this.authService,
    this.profileFuture,
    this.gubsStream,
    this.communitiesStream,
    this.accountConnectionSection,
  });

  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  late Future<UserProfileModel> _profileFuture;
  late Stream<List<PersonalGubModel>> _gubsStream;
  late Stream<List<CommunityMembershipModel>> _communitiesStream;
  AuthService? _authService;
  Object? _lastLoggedGubsError;
  MembershipWindow _selectedWindow = MembershipWindow.privateGubs;

  @override
  void initState() {
    super.initState();
    _authService =
        widget.authService ??
        (widget.accountConnectionSection == null ? AuthService() : null);
    _initializeLoads();
  }

  @override
  void didUpdateWidget(covariant PersonalProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _initializeLoads();
    }
  }

  void _initializeLoads() {
    _profileFuture =
        widget.profileFuture ??
        UserProfileService.instance.loadPersonalProfile(userId: widget.userId);
    _gubsStream =
        widget.gubsStream ??
        UserProfileService.instance.personalGubsStream(userId: widget.userId);
    _communitiesStream =
        widget.communitiesStream ??
        UserProfileService.instance.personalCommunitiesStream(
          userId: widget.userId,
        );
  }

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.profiles,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Personal profile"),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: FutureBuilder<UserProfileModel>(
            future: _profileFuture,
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (profileSnapshot.hasError || !profileSnapshot.hasData) {
                return const _PersonalProfileMessage(
                  icon: Icons.person_off_outlined,
                  message: "Unable to load your profile.",
                );
              }

              return StreamBuilder<List<PersonalGubModel>>(
                stream: _gubsStream,
                builder: (context, gubsSnapshot) {
                  if (gubsSnapshot.hasError) {
                    _logGubsError(gubsSnapshot.error);
                  }

                  return StreamBuilder<List<CommunityMembershipModel>>(
                    stream: _communitiesStream,
                    builder: (context, communitiesSnapshot) {
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                        children: [
                          _PersonalProfileHeader(
                            profile: profileSnapshot.data!,
                          ),
                          const SizedBox(height: 20),
                          widget.accountConnectionSection ??
                              GoogleAccountConnectionSection(
                                authService: _authService!,
                              ),
                          const SizedBox(height: 26),
                          MembershipWindowSelector(
                            selectedWindow: _selectedWindow,
                            privateCount: gubsSnapshot.data?.length,
                            communityCount: communitiesSnapshot.data?.length,
                            onSelected: (window) {
                              setState(() => _selectedWindow = window);
                            },
                          ),
                          const SizedBox(height: 14),
                          if (_selectedWindow == MembershipWindow.privateGubs)
                            ..._privateGubContent(gubsSnapshot)
                          else
                            ..._communityContent(communitiesSnapshot),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _privateGubContent(
    AsyncSnapshot<List<PersonalGubModel>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (snapshot.hasError) {
      return const [
        _PersonalProfileMessage(
          icon: Icons.error_outline_rounded,
          message: "Unable to load your Gubs.",
        ),
      ];
    }
    final gubs = snapshot.data ?? const [];
    if (gubs.isEmpty) {
      return const [
        _PersonalProfileMessage(
          icon: Icons.hub_outlined,
          message: "No private Gubs yet",
        ),
      ];
    }
    return [
      for (final gub in gubs)
        _PersonalGubCard(
          gub: gub,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  UserProfileScreen(gubId: gub.gubId, userId: widget.userId),
            ),
          ),
        ),
    ];
  }

  List<Widget> _communityContent(
    AsyncSnapshot<List<CommunityMembershipModel>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (snapshot.hasError) {
      return const [
        _PersonalProfileMessage(
          icon: Icons.error_outline_rounded,
          message: "Unable to load your Communities.",
        ),
      ];
    }
    final memberships = snapshot.data ?? const [];
    if (memberships.isEmpty) {
      return const [
        _PersonalProfileMessage(
          icon: Icons.public_rounded,
          message: "No Communities yet",
        ),
      ];
    }
    return [
      for (var index = 0; index < memberships.length; index++)
        Padding(
          padding: EdgeInsets.only(
            bottom: index == memberships.length - 1 ? 0 : 4,
          ),
          child: CommunityMembershipCard(
            membership: memberships[index],
            onTap: () => _openCommunity(memberships[index]),
          ),
        ),
    ];
  }

  Future<void> _openCommunity(CommunityMembershipModel membership) async {
    if (!await showCommunityLinkedAccountGate(context) || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GubCommunityHomeScreen(
          communityId: membership.community.communityId,
          initialCommunity: membership.community,
        ),
      ),
    );
  }

  void _logGubsError(Object? error) {
    if (error == null || identical(error, _lastLoggedGubsError)) return;
    _lastLoggedGubsError = error;

    if (error is FirebaseException) {
      debugPrint(
        "Personal Gubs load failed - ${error.runtimeType}, "
        "code: ${error.code}, message: ${error.message ?? 'Unavailable'}",
      );
      return;
    }

    debugPrint("Personal Gubs load failed - ${error.runtimeType}: $error");
  }
}

class _PersonalProfileHeader extends StatelessWidget {
  final UserProfileModel profile;

  const _PersonalProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ChatUserAvatar(
          displayName: profile.displayName,
          userId: profile.userId,
          photoUrl: profile.photoUrl,
          radius: 42,
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                profile.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Chip(
              visualDensity: VisualDensity.compact,
              label: Text("You"),
            ),
          ],
        ),
      ],
    );
  }
}

class _PersonalGubCard extends StatelessWidget {
  final PersonalGubModel gub;
  final VoidCallback onTap;

  const _PersonalGubCard({required this.gub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(
                  0xFF7C3AED,
                ).withValues(alpha: 0.12),
                child: Text(
                  _initialFor(gub.name),
                  style: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gub.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    MembershipDetails(
                      role: gub.isFounder
                          ? 'Founder'
                          : formatRoleLabel(gub.role, fallback: 'Member'),
                      joinedAt: gub.joinedAt,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  String _initialFor(String name) {
    final normalized = name.trim();
    return normalized.isEmpty
        ? "?"
        : String.fromCharCode(normalized.runes.first).toUpperCase();
  }
}

class _PersonalProfileMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _PersonalProfileMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: const Color(0xFF64748B)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
