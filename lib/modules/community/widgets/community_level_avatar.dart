import 'package:flutter/material.dart';

import '../../chat/widgets/chat_user_avatar.dart';
import '../leveling/community_level.dart';

class CommunityLevelAvatar extends StatelessWidget {
  const CommunityLevelAvatar({
    super.key,
    required this.displayName,
    required this.userId,
    required this.photoUrl,
    this.radius = 17,
    required this.xp,
    this.onTap,
  });

  final String displayName;
  final String userId;
  final String? photoUrl;
  final double radius;
  final int? xp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = ChatUserAvatar(
      displayName: displayName,
      userId: userId,
      photoUrl: photoUrl,
      radius: radius,
      onTap: onTap,
    );
    if (xp == null) return avatar;

    final level = CommunityLevel.fromXp(xp);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -4,
          bottom: -4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              child: Text(
                'Lv ${level.level}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
