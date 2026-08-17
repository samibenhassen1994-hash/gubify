import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/models/board_post_model.dart';
import 'package:gubify/services/board_read_service.dart';

void main() {
  const currentUserId = 'current-user';
  const otherUserId = 'other-user';
  final joinedAt = Timestamp.fromDate(DateTime.utc(2026, 1, 2));

  Timestamp at(int day) => Timestamp.fromDate(DateTime.utc(2026, 1, day));

  BoardPostModel post(
    String id,
    int day, {
    String authorId = otherUserId,
    int? updatedDay,
    String? lastCommentAuthorId,
  }) {
    return BoardPostModel(
      postId: id,
      authorId: authorId,
      authorName: authorId,
      message: 'Post $id',
      likes: 0,
      comments: 0,
      createdAt: at(day),
      updatedAt: at(updatedDay ?? day),
      lastCommentAuthorId: lastCommentAuthorId,
    );
  }

  Future<void> flush() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  group('Board unread badge', () {
    late StreamController<Timestamp?> reads;
    late StreamController<List<BoardPostModel>> posts;
    late List<int> counts;
    late BoardReadService service;
    late StreamSubscription<int> subscription;

    setUp(() async {
      reads = StreamController<Timestamp?>();
      posts = StreamController<List<BoardPostModel>>.broadcast();
      counts = [];
      service = BoardReadService.testing(
        currentUserId: () => currentUserId,
        membershipJoinedAt: (_, _) async => joinedAt,
        lastReadAtStream: (_, _) => reads.stream,
        postsAfterStream: (_, _) => posts.stream,
        markAsRead: (_, _) async => reads.add(at(5)),
      );
      subscription = service.unreadCountStream('gub').listen(counts.add);
      await flush();
    });

    tearDown(() async {
      await subscription.cancel();
      await reads.close();
      await posts.close();
    });

    test('missing read state counts the first post after joining', () async {
      reads.add(null);
      await flush();
      posts.add([post('first', 3)]);
      await flush();

      expect(counts, [1]);
    });

    test('missing read state counts two posts after joining', () async {
      reads.add(null);
      await flush();
      posts.add([post('first', 3), post('second', 4)]);
      await flush();

      expect(counts, [2]);
    });

    test('first post after an existing lastReadAt is unread', () async {
      reads.add(at(3));
      await flush();
      posts.add([post('first', 4)]);
      await flush();

      expect(counts, [1]);
    });

    test('post before an existing lastReadAt is not unread', () async {
      reads.add(at(4));
      await flush();
      posts.add([post('old', 3)]);
      await flush();

      expect(counts, [0]);
    });

    test(
      'marking read clears the badge and the next post restores it',
      () async {
        reads.add(null);
        await flush();
        posts.add([post('first', 3)]);
        await flush();
        expect(counts, [1]);

        await service.markAsRead('gub');
        await flush();
        posts.add(const []);
        await flush();
        expect(counts, [1, 0]);

        posts.add([post('next', 6)]);
        await flush();
        expect(counts, [1, 0, 1]);
      },
    );

    test('the current user own post is not unread', () async {
      reads.add(null);
      await flush();
      posts.add([post('own', 3, authorId: currentUserId)]);
      await flush();

      expect(counts, [0]);
    });

    test('the first comment by another member on my post is unread', () async {
      reads.add(at(4));
      await flush();
      posts.add([
        post(
          'mine',
          3,
          authorId: currentUserId,
          updatedDay: 5,
          lastCommentAuthorId: otherUserId,
        ),
      ]);
      await flush();

      expect(counts, [1]);
    });

    test('own comment on own post is not unread', () async {
      reads.add(at(4));
      await flush();
      posts.add([
        post(
          'mine',
          3,
          authorId: currentUserId,
          updatedDay: 5,
          lastCommentAuthorId: currentUserId,
        ),
      ]);
      await flush();

      expect(counts, [0]);
    });

    test(
      'membership boundary excludes old posts and includes the first new one',
      () async {
        reads.add(null);
        await flush();
        posts.add([post('before', 1), post('after', 3)]);
        await flush();

        expect(counts, [1]);
      },
    );

    test(
      'an old read state cannot move the membership boundary backwards',
      () async {
        reads.add(at(1));
        await flush();
        posts.add([post('before', 1), post('after', 3)]);
        await flush();

        expect(counts, [1]);
      },
    );
  });
}
