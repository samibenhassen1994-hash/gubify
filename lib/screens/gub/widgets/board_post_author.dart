import 'package:flutter/material.dart';

import '../../../models/board_post_model.dart';
import '../../../modules/chat/widgets/deleted_user_identity_builder.dart';
import '../../../repositories/user_repository.dart';
import '../../../modules/profile/screens/user_profile_screen.dart';

class BoardPostAuthor extends StatelessWidget {
  const BoardPostAuthor({
    super.key,
    required this.post,
    required this.gubId,
    this.identity,
    this.onProfileTap,
  });

  final BoardPostModel post;
  final String gubId;
  final Stream<UserIdentity>? identity;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return DeletedUserIdentityBuilder(
      userId: post.authorId,
      currentDisplayName: post.authorName,
      identity: identity,
      resolveCurrentDisplayName: true,
      builder: (context, displayName, deleted) {
        final canOpen = !deleted && post.authorId.trim().isNotEmpty;
        return InkWell(
          onTap: canOpen
              ? onProfileTap ??
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(
                          gubId: gubId,
                          userId: post.authorId,
                        ),
                      ),
                    )
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              CircleAvatar(
                child: Icon(deleted ? Icons.person_off_outlined : Icons.person),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
