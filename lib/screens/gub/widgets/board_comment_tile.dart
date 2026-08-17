import 'package:flutter/material.dart';

import '../../../models/board_comment_model.dart';
import '../../../modules/chat/widgets/deleted_user_identity_builder.dart';
import '../../../repositories/user_repository.dart';

class BoardCommentTile extends StatelessWidget {
  const BoardCommentTile({
    super.key,
    required this.comment,
    required this.formattedDate,
    this.identity,
  });

  final BoardCommentModel comment;
  final String? formattedDate;
  final Stream<UserIdentity>? identity;

  @override
  Widget build(BuildContext context) => DeletedUserIdentityBuilder(
    userId: comment.authorId,
    currentDisplayName: comment.authorName,
    identity: identity,
    resolveCurrentDisplayName: comment.authorId.isNotEmpty,
    builder: (context, name, _) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(comment.text),
      trailing: formattedDate == null
          ? null
          : Text(formattedDate!, style: const TextStyle(fontSize: 11)),
    ),
  );
}
