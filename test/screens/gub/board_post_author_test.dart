import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/models/board_post_model.dart';
import 'package:gubify/repositories/user_repository.dart';
import 'package:gubify/screens/gub/widgets/board_post_author.dart';

void main() {
  const post = BoardPostModel(
    postId: 'post-1',
    authorId: 'user-a',
    authorName: 'Old Name',
    message: 'Board update',
    likes: 0,
    comments: 0,
    createdAt: null,
  );

  testWidgets('refreshes an active Board author after a display-name change', (
    tester,
  ) async {
    final identities = StreamController<UserIdentity>.broadcast(sync: true);
    addTearDown(identities.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardPostAuthor(post: post, identity: identities.stream),
        ),
      ),
    );

    expect(find.text('User'), findsNothing);
    expect(find.text('Old Name'), findsOneWidget);

    identities.add(const UserIdentity.existing('Old Name'));
    await tester.pump();
    expect(find.text('Old Name'), findsOneWidget);

    identities.add(const UserIdentity.existing('New Name'));
    await tester.pump();
    expect(find.text('New Name'), findsOneWidget);
    expect(find.text('User'), findsNothing);
  });

  test(
    'reuses one live identity stream for Board posts by the same author',
    () async {
      final cache = UserIdentityStreamCache();
      final identities = StreamController<UserIdentity>.broadcast(sync: true);
      addTearDown(identities.close);
      var streamCreations = 0;

      Stream<UserIdentity> create() {
        streamCreations++;
        return identities.stream;
      }

      final first = cache.forUser('user-a', create);
      final second = cache.forUser('user-a', create);

      expect(identical(first, second), isTrue);
      expect(streamCreations, 0);

      final subscription = first.listen((_) {});
      expect(streamCreations, 1);
      await subscription.cancel();
      cache.clear();
    },
  );

  testWidgets('keeps a deleted Board author distinct from an active user', (
    tester,
  ) async {
    const deletedPost = BoardPostModel(
      postId: 'post-2',
      authorId: '__deleted_user__',
      authorName: 'Deleted user',
      message: 'Historical post',
      likes: 0,
      comments: 0,
      createdAt: null,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BoardPostAuthor(post: deletedPost)),
      ),
    );
    await tester.pump();

    expect(find.text('Deleted user'), findsOneWidget);
    expect(find.text('User'), findsNothing);
  });
}
