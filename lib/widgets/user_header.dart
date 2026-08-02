import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../modules/chat/widgets/chat_user_avatar.dart';
import '../modules/notifications/screens/notifications_screen.dart';
import '../modules/notifications/models/notification_model.dart';
import '../modules/profile/screens/personal_profile_screen.dart';
import '../modules/profile/screens/user_profile_screen.dart';
import '../repositories/user_repository.dart';
import 'gub_content_card.dart';

class UserHeader extends StatefulWidget {
  final String? gubId;
  final bool darkMode;
  final bool personalProfileEnabled;
  final bool showCard;
  final bool darkCard;
  final VoidCallback? onExploreCommunities;

  const UserHeader({
    super.key,
    this.gubId,
    this.darkMode = false,
    this.personalProfileEnabled = false,
    this.showCard = false,
    this.darkCard = false,
    this.onExploreCommunities,
  }) : assert(!darkCard || showCard, "darkCard requires showCard.");

  @override
  State<UserHeader> createState() => _UserHeaderState();
}

class _UserHeaderState extends State<UserHeader> {
  String? _userId;
  late Future<Map<String, dynamic>?> _userFuture;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void didUpdateWidget(covariant UserHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != _userId) {
      _loadCurrentUser();
    }
  }

  void _loadCurrentUser() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _userId = currentUserId;
    _userFuture = currentUserId == null
        ? Future.value(null)
        : UserRepository.instance.getUser(currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != _userId) {
      return _buildPlaceholder();
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          const placeholder = SizedBox(height: 44);

          return Padding(
            padding: EdgeInsets.only(bottom: widget.showCard ? 20 : 24),
            child: widget.showCard
                ? _UserHeaderCard(dark: widget.darkCard, child: placeholder)
                : placeholder,
          );
        }

        final data = snapshot.data;
        final storedDisplayName = data?["displayName"];
        final displayName =
            storedDisplayName is String && storedDisplayName.trim().isNotEmpty
            ? storedDisplayName.trim()
            : "User";
        final storedPhotoUrl = data?["photoUrl"] ?? data?["photoURL"];
        final photoUrl = storedPhotoUrl is String ? storedPhotoUrl : null;
        final useLightForeground =
            widget.darkCard || (widget.darkMode && !widget.showCard);

        final headerContent = Row(
          children: [
            _CurrentUserAvatar(
              gubId: widget.gubId,
              userId: user.uid,
              displayName: displayName,
              photoUrl: widget.darkCard ? null : photoUrl,
              personalProfileEnabled: widget.personalProfileEnabled,
              backgroundColor: widget.darkCard ? const Color(0xFF2563EB) : null,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                  color: useLightForeground ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            if (widget.gubId != null)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection("gubs")
                    .doc(widget.gubId)
                    .collection("notifications")
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];

                  final count = docs.where((doc) {
                    final data = doc.data();
                    if (!NotificationModel.targetsUser(data, user.uid)) {
                      return false;
                    }

                    final readBy = List<String>.from(data["readBy"] ?? []);

                    final senderId = data["senderId"] ?? "";

                    final type = data["type"] ?? "";

                    if (type == "board_post") {
                      return false;
                    }

                    if (readBy.contains(user.uid)) {
                      return false;
                    }

                    if (type == "proposal_approved" ||
                        type == "proposal_rejected") {
                      return true;
                    }

                    return senderId != user.uid;
                  }).length;

                  return SizedBox(
                    width: 56,
                    height: 56,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  NotificationsScreen(gubId: widget.gubId!),
                            ),
                          );
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.notifications_outlined,
                              size: 26,
                              color: widget.darkCard
                                  ? Colors.white
                                  : useLightForeground
                                  ? Colors.white70
                                  : Colors.black54,
                            ),

                            if (count > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 19,
                                    height: 19,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      count > 9 ? "9+" : "$count",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

            if (widget.onExploreCommunities != null)
              IconButton(
                tooltip: "Explore communities",
                onPressed: widget.onExploreCommunities,
                icon: Icon(
                  Icons.public_rounded,
                  size: 25,
                  color: widget.darkCard
                      ? Colors.white
                      : useLightForeground
                      ? Colors.white70
                      : const Color(0xFF2563EB),
                ),
              ),

            IconButton(
              onPressed: () {
                // TODO: Settings
              },
              icon: Icon(
                Icons.settings_outlined,
                size: 26,
                color: widget.darkCard
                    ? Colors.white
                    : useLightForeground
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: widget.showCard
              ? _UserHeaderCard(dark: widget.darkCard, child: headerContent)
              : headerContent,
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    const placeholder = SizedBox(height: 44);
    return Padding(
      padding: EdgeInsets.only(bottom: widget.showCard ? 20 : 24),
      child: widget.showCard
          ? _UserHeaderCard(dark: widget.darkCard, child: placeholder)
          : placeholder,
    );
  }
}

class _UserHeaderCard extends StatelessWidget {
  final Widget child;
  final bool dark;

  const _UserHeaderCard({required this.child, required this.dark});

  @override
  Widget build(BuildContext context) {
    return GubContentCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      color: dark ? const Color(0xE60B1739) : Colors.white,
      border: dark
          ? Border.all(color: const Color(0x24FFFFFF), width: 0.8)
          : null,
      boxShadow: dark
          ? const [
              BoxShadow(
                color: Color(0x38000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ]
          : null,
      child: child,
    );
  }
}

class _CurrentUserAvatar extends StatefulWidget {
  final String? gubId;
  final String userId;
  final String? displayName;
  final String? photoUrl;
  final bool personalProfileEnabled;
  final Color? backgroundColor;

  const _CurrentUserAvatar({
    required this.gubId,
    required this.userId,
    required this.personalProfileEnabled,
    this.displayName,
    this.photoUrl,
    this.backgroundColor,
  });

  @override
  State<_CurrentUserAvatar> createState() => _CurrentUserAvatarState();
}

class _CurrentUserAvatarState extends State<_CurrentUserAvatar> {
  bool _isOpeningProfile = false;

  Future<void> _openProfile() async {
    final gubId = widget.gubId;
    if ((gubId == null && !widget.personalProfileEnabled) ||
        _isOpeningProfile) {
      return;
    }

    setState(() => _isOpeningProfile = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => gubId == null
              ? PersonalProfileScreen(userId: widget.userId)
              : UserProfileScreen(gubId: gubId, userId: widget.userId),
        ),
      );
    } finally {
      if (mounted) setState(() => _isOpeningProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChatUserAvatar(
      displayName: widget.displayName,
      userId: widget.userId,
      photoUrl: widget.photoUrl,
      radius: 22,
      backgroundColor: widget.backgroundColor,
      onTap:
          (widget.gubId == null && !widget.personalProfileEnabled) ||
              _isOpeningProfile
          ? null
          : _openProfile,
    );
  }
}
