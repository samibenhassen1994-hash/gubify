import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../modules/chat/widgets/chat_user_avatar.dart';
import '../modules/notifications/screens/notifications_screen.dart';
import '../modules/profile/screens/personal_profile_screen.dart';
import '../modules/profile/screens/user_profile_screen.dart';
import '../repositories/user_repository.dart';

class UserHeader extends StatelessWidget {
  final String? gubId;
  final bool darkMode;
  final bool personalProfileEnabled;

  const UserHeader({
    super.key,
    this.gubId,
    this.darkMode = false,
    this.personalProfileEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return FutureBuilder<Map<String, dynamic>?>(
      future: UserRepository.instance.getUser(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: SizedBox(height: 44),
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

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              _CurrentUserAvatar(
                gubId: gubId,
                userId: user.uid,
                displayName: displayName,
                photoUrl: photoUrl,
                personalProfileEnabled: personalProfileEnabled,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: darkMode ? Colors.white : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              if (gubId != null)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection("gubs")
                      .doc(gubId)
                      .collection("notifications")
                      .snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];

                    final count = docs.where((doc) {
                      final data = doc.data();

                      final readBy = List<String>.from(data["readBy"] ?? []);

                      final senderId = data["senderId"] ?? "";

                      final type = data["type"] ?? "";

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
                                    NotificationsScreen(gubId: gubId!),
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
                                color: darkMode
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

              IconButton(
                onPressed: () {
                  // TODO: Settings
                },
                icon: Icon(
                  Icons.settings_outlined,
                  size: 26,
                  color: darkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CurrentUserAvatar extends StatefulWidget {
  final String? gubId;
  final String userId;
  final String? displayName;
  final String? photoUrl;
  final bool personalProfileEnabled;

  const _CurrentUserAvatar({
    required this.gubId,
    required this.userId,
    required this.personalProfileEnabled,
    this.displayName,
    this.photoUrl,
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
      onTap:
          (widget.gubId == null && !widget.personalProfileEnabled) ||
              _isOpeningProfile
          ? null
          : _openProfile,
    );
  }
}
