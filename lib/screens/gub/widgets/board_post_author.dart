import 'package:flutter/material.dart';

import '../../../models/board_post_model.dart';
import '../../../modules/chat/widgets/deleted_user_identity_builder.dart';
import '../../../repositories/user_repository.dart';

class BoardPostAuthor extends StatelessWidget {
  const BoardPostAuthor({super.key, required this.post, this.identity});

  final BoardPostModel post;
  final Stream<UserIdentity>? identity;

  @override
  Widget build(BuildContext context) {
    return DeletedUserIdentityBuilder(
      userId: post.authorId,
      currentDisplayName: post.authorName,
      identity: identity,
      resolveCurrentDisplayName: true,
      builder: (context, displayName, deleted) => Row(
        children: [
          CircleAvatar(
            child: Icon(deleted ? Icons.person_off_outlined : Icons.person),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
