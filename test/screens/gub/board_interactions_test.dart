import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/models/board_post_model.dart';
import 'package:gubify/models/board_comment_model.dart';
import 'package:gubify/repositories/user_repository.dart';
import 'package:gubify/screens/gub/board_screen.dart';
import 'package:gubify/screens/gub/widgets/board_post_author.dart';
import 'package:gubify/screens/gub/widgets/board_comment_tile.dart';

void main() {
  BoardPostModel post(String id, {String authorId = 'author'}) =>
      BoardPostModel(
        postId: id,
        authorId: authorId,
        authorName: 'Stored name',
        message: id,
        likes: 0,
        comments: 0,
        createdAt: Timestamp.fromDate(DateTime.utc(2026, 1, 2, 13, 5)),
      );

  test('pinned post is ordered first', () {
    final ordered = BoardScreen.orderPosts([post('one'), post('two')], 'two');
    expect(ordered.map((item) => item.postId), ['two', 'one']);
  });

  test('post date uses compact date and time', () {
    expect(
      BoardScreen.formatPostDate(DateTime(2026, 1, 2, 13, 5)),
      '02/01/2026 · 13:05',
    );
  });

  testWidgets('active Board author is canonical and clickable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardPostAuthor(
            post: post('one'),
            gubId: 'gub',
            identity: Stream.value(const UserIdentity.existing('Current name')),
            onProfileTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Current name'), findsOneWidget);
    await tester.tap(find.text('Current name'));
    expect(taps, 1);
  });

  testWidgets('deleted Board author is not clickable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardPostAuthor(
            post: post('one'),
            gubId: 'gub',
            identity: Stream.value(const UserIdentity.missing()),
            onProfileTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Deleted user'), findsOneWidget);
    await tester.tap(find.text('Deleted user'));
    expect(taps, 0);
  });

  testWidgets('comment author uses canonical current identity', (tester) async {
    const comment = BoardCommentModel(
      commentId: 'comment',
      authorId: 'author',
      authorName: 'Stored name',
      text: 'Hello',
      createdAt: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardCommentTile(
            comment: comment,
            formattedDate: null,
            identity: Stream.value(const UserIdentity.existing('Current name')),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Current name'), findsOneWidget);
  });

  testWidgets('deleted comment author renders Deleted user', (tester) async {
    const comment = BoardCommentModel(
      commentId: 'comment',
      authorId: 'author',
      authorName: 'Stored name',
      text: 'Hello',
      createdAt: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardCommentTile(
            comment: comment,
            formattedDate: null,
            identity: Stream.value(const UserIdentity.missing()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Deleted user'), findsOneWidget);
  });
}
