import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/board_post_model.dart';
import '../repositories/board_read_repository.dart';
import '../repositories/post_repository.dart';

class BoardReadService {
  BoardReadService._({
    String? Function()? currentUserId,
    Future<Timestamp?> Function(String gubId, String userId)?
    membershipJoinedAt,
    Stream<Timestamp?> Function(String gubId, String userId)? lastReadAtStream,
    Stream<List<BoardPostModel>> Function(String gubId, Timestamp unreadAfter)?
    postsAfterStream,
    Future<void> Function(String gubId, String userId)? markAsRead,
  }) : _currentUserId =
           currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _membershipJoinedAt =
           membershipJoinedAt ??
           ((gubId, userId) => BoardReadRepository.instance.membershipJoinedAt(
             gubId: gubId,
             userId: userId,
           )),
       _lastReadAtStream =
           lastReadAtStream ??
           ((gubId, userId) => BoardReadRepository.instance.lastReadAtStream(
             gubId: gubId,
             userId: userId,
           )),
       _postsAfterStream =
           postsAfterStream ??
           ((gubId, unreadAfter) => PostRepository.instance.postsAfterStream(
             gubId: gubId,
             lastReadAt: unreadAfter,
           )),
       _markAsRead =
           markAsRead ??
           ((gubId, userId) => BoardReadRepository.instance.markAsRead(
             gubId: gubId,
             userId: userId,
           ));

  static final BoardReadService instance = BoardReadService._();

  @visibleForTesting
  factory BoardReadService.testing({
    required String? Function() currentUserId,
    required Future<Timestamp?> Function(String gubId, String userId)
    membershipJoinedAt,
    required Stream<Timestamp?> Function(String gubId, String userId)
    lastReadAtStream,
    required Stream<List<BoardPostModel>> Function(
      String gubId,
      Timestamp unreadAfter,
    )
    postsAfterStream,
    required Future<void> Function(String gubId, String userId) markAsRead,
  }) => BoardReadService._(
    currentUserId: currentUserId,
    membershipJoinedAt: membershipJoinedAt,
    lastReadAtStream: lastReadAtStream,
    postsAfterStream: postsAfterStream,
    markAsRead: markAsRead,
  );

  final String? Function() _currentUserId;
  final Future<Timestamp?> Function(String gubId, String userId)
  _membershipJoinedAt;
  final Stream<Timestamp?> Function(String gubId, String userId)
  _lastReadAtStream;
  final Stream<List<BoardPostModel>> Function(
    String gubId,
    Timestamp unreadAfter,
  )
  _postsAfterStream;
  final Future<void> Function(String gubId, String userId) _markAsRead;

  static Timestamp effectiveUnreadAfter({
    required Timestamp membershipBoundary,
    Timestamp? lastReadAt,
  }) {
    if (lastReadAt == null) return membershipBoundary;
    if (lastReadAt.seconds > membershipBoundary.seconds ||
        (lastReadAt.seconds == membershipBoundary.seconds &&
            lastReadAt.nanoseconds >= membershipBoundary.nanoseconds)) {
      return lastReadAt;
    }
    return membershipBoundary;
  }

  static bool shouldCountUnreadPost({
    required BoardPostModel post,
    required String userId,
    required Timestamp unreadAfter,
  }) {
    bool isAfter(Timestamp? value) =>
        value != null &&
        (value.seconds > unreadAfter.seconds ||
            (value.seconds == unreadAfter.seconds &&
                value.nanoseconds > unreadAfter.nanoseconds));

    final unreadPost = post.authorId != userId && isAfter(post.createdAt);
    final unreadComment =
        post.authorId == userId &&
        post.lastCommentAuthorId != null &&
        post.lastCommentAuthorId != userId &&
        isAfter(post.updatedAt);
    return unreadPost || unreadComment;
  }

  Stream<int> unreadCountStream(String gubId) {
    final userId = _currentUserId();
    if (userId == null) {
      return Stream<int>.error(
        StateError('You must be signed in to read Board updates.'),
      );
    }

    StreamSubscription<Timestamp?>? readSubscription;
    StreamSubscription<List<BoardPostModel>>? postSubscription;
    var queryGeneration = 0;
    Timestamp? activeUnreadAfter;

    late final StreamController<int> controller;

    bool sameTimestamp(Timestamp? first, Timestamp? second) {
      if (first == null || second == null) return first == second;
      return first.seconds == second.seconds &&
          first.nanoseconds == second.nanoseconds;
    }

    Future<void> replacePostsStream(Timestamp unreadAfter) async {
      final generation = ++queryGeneration;
      await postSubscription?.cancel();
      if (controller.isClosed || generation != queryGeneration) return;

      postSubscription = _postsAfterStream(gubId, unreadAfter).listen(
        (posts) {
          if (controller.isClosed || generation != queryGeneration) return;

          final unreadCount = posts
              .where(
                (post) => shouldCountUnreadPost(
                  post: post,
                  userId: userId,
                  unreadAfter: unreadAfter,
                ),
              )
              .length;
          controller.add(unreadCount);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed && generation == queryGeneration) {
            controller.addError(error, stackTrace);
          }
        },
      );
    }

    late final Timestamp membershipBoundary;

    void handleReadState(Timestamp? lastReadAt) {
      final unreadAfter = effectiveUnreadAfter(
        membershipBoundary: membershipBoundary,
        lastReadAt: lastReadAt,
      );
      if (sameTimestamp(activeUnreadAfter, unreadAfter)) return;
      activeUnreadAfter = unreadAfter;
      unawaited(replacePostsStream(unreadAfter));
    }

    Future<void> start() async {
      try {
        final joinedAt = await _membershipJoinedAt(gubId, userId);
        if (controller.isClosed) return;
        if (joinedAt == null) {
          controller.addError(
            StateError('The current Board membership has no valid joinedAt.'),
          );
          return;
        }
        membershipBoundary = joinedAt;
        readSubscription = _lastReadAtStream(gubId, userId).listen(
          handleReadState,
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<int>(
      onListen: () {
        unawaited(start());
      },
      onCancel: () async {
        queryGeneration++;
        await readSubscription?.cancel();
        await postSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  Future<void> markAsRead(String gubId) {
    final userId = _currentUserId();
    if (userId == null) {
      throw StateError('You must be signed in to update Board read status.');
    }

    return _markAsRead(gubId, userId);
  }
}
