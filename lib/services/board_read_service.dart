import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/board_post_model.dart';
import '../repositories/board_read_repository.dart';
import '../repositories/post_repository.dart';
import 'gub_service.dart';

class BoardReadService {
  BoardReadService._();

  static final BoardReadService instance = BoardReadService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<int> unreadCountStream(String gubId) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<int>.error(
        StateError('You must be signed in to read Board updates.'),
      );
    }

    return _withMembershipBoundary(
      gubId,
      (boundary) => _unreadCountWithBoundary(
        gubId: gubId,
        userId: user.uid,
        membershipBoundary: boundary,
      ),
    );
  }

  Stream<int> _withMembershipBoundary(
    String gubId,
    Stream<int> Function(Timestamp boundary) build,
  ) async* {
    final boundary = (await GubService().currentMembershipHistoryBoundary(
      gubId,
    ))?.membershipStartedAt;
    if (boundary == null) {
      yield 0;
      return;
    }
    yield* build(boundary);
  }

  Stream<int> _unreadCountWithBoundary({
    required String gubId,
    required String userId,
    required Timestamp membershipBoundary,
  }) {
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    readSubscription;
    StreamSubscription<List<BoardPostModel>>? postSubscription;
    var queryGeneration = 0;
    var hasReadState = false;
    Timestamp? activeLastReadAt;

    late final StreamController<int> controller;

    bool sameTimestamp(Timestamp? first, Timestamp? second) {
      if (first == null || second == null) return first == second;
      return first.seconds == second.seconds &&
          first.nanoseconds == second.nanoseconds;
    }

    Future<void> replacePostsStream(Timestamp? lastReadAt) async {
      final generation = ++queryGeneration;
      await postSubscription?.cancel();
      if (controller.isClosed || generation != queryGeneration) return;

      postSubscription = PostRepository.instance
          .postsAfterStream(
            gubId: gubId,
            lastReadAt: _latestTimestamp(membershipBoundary, lastReadAt),
            membershipBoundary: membershipBoundary,
          )
          .listen(
            (posts) {
              if (controller.isClosed || generation != queryGeneration) return;

              final unreadCount = posts.where((post) {
                return post.createdAt != null && post.authorId != userId;
              }).length;
              controller.add(unreadCount);
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!controller.isClosed && generation == queryGeneration) {
                controller.addError(error, stackTrace);
              }
            },
          );
    }

    void handleReadState(DocumentSnapshot<Map<String, dynamic>> snapshot) {
      if (!snapshot.exists) {
        if (hasReadState && activeLastReadAt == null) return;
        hasReadState = true;
        activeLastReadAt = null;
        unawaited(replacePostsStream(null));
        return;
      }

      final lastReadAt = snapshot.data()?['lastReadAt'];
      if (lastReadAt is! Timestamp) {
        return;
      }

      if (hasReadState && sameTimestamp(activeLastReadAt, lastReadAt)) return;
      hasReadState = true;
      activeLastReadAt = lastReadAt;
      unawaited(replacePostsStream(lastReadAt));
    }

    controller = StreamController<int>(
      onListen: () {
        readSubscription = BoardReadRepository.instance
            .readStateStream(gubId: gubId, userId: userId)
            .listen(
              handleReadState,
              onError: (Object error, StackTrace stackTrace) {
                if (!controller.isClosed) {
                  controller.addError(error, stackTrace);
                }
              },
            );
      },
      onCancel: () async {
        queryGeneration++;
        await readSubscription?.cancel();
        await postSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  Timestamp _latestTimestamp(Timestamp first, Timestamp? second) {
    if (second == null ||
        first.seconds > second.seconds ||
        (first.seconds == second.seconds &&
            first.nanoseconds >= second.nanoseconds)) {
      return first;
    }
    return second;
  }

  Future<void> markAsRead(String gubId) {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to update Board read status.');
    }

    return BoardReadRepository.instance.markAsRead(
      gubId: gubId,
      userId: user.uid,
    );
  }
}
