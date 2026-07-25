import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../../chat/widgets/chat_user_avatar.dart';
import '../models/user_profile_model.dart';
import '../services/user_profile_service.dart';
import 'user_profile_screen.dart';

class PersonalProfileScreen extends StatefulWidget {
  final String userId;

  const PersonalProfileScreen({super.key, required this.userId});

  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  late final Future<UserProfileModel> _profileFuture;
  Object? _lastLoggedGubsError;

  @override
  void initState() {
    super.initState();
    _profileFuture = UserProfileService.instance.loadPersonalProfile(
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
                stream: UserProfileService.instance.personalGubsStream(
                  userId: widget.userId,
                ),
                builder: (context, gubsSnapshot) {
                  if (gubsSnapshot.hasError) {
                    _logGubsError(gubsSnapshot.error);
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    children: [
                      _PersonalProfileHeader(profile: profileSnapshot.data!),
                      const SizedBox(height: 30),
                      Text(
                        "Your Gubs",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (gubsSnapshot.connectionState ==
                          ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (gubsSnapshot.hasError)
                        const _PersonalProfileMessage(
                          icon: Icons.error_outline_rounded,
                          message: "Unable to load your Gubs.",
                        )
                      else if (gubsSnapshot.data?.isEmpty ?? true)
                        const _PersonalProfileMessage(
                          icon: Icons.hub_outlined,
                          message: "No Gubs yet",
                        )
                      else
                        for (final gub in gubsSnapshot.data!)
                          _PersonalGubCard(
                            gub: gub,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => UserProfileScreen(
                                  gubId: gub.gubId,
                                  userId: widget.userId,
                                ),
                              ),
                            ),
                          ),
                    ],
                  );
                },
              );
            },
          ),
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
      color: Colors.white.withValues(alpha: 0.93),
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
                    const SizedBox(height: 3),
                    Text(
                      gub.role == null
                          ? "View your Gub activity"
                          : "${_roleLabel(gub.role!)} - View your Gub activity",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
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

  String _roleLabel(String role) {
    final normalized = role.trim();
    if (normalized.isEmpty) return "Member";
    return "${normalized[0].toUpperCase()}${normalized.substring(1)}";
  }
}

class _PersonalProfileMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _PersonalProfileMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.93),
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
