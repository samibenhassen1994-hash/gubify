import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../repositories/gub_repository.dart';

class ChatReadRepository {
  ChatReadRepository._();

  static final ChatReadRepository instance = ChatReadRepository._();

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

  static bool shouldCountUnreadMessage({
    required Object? createdAt,
    required Object? senderId,
    required String userId,
    required Timestamp unreadAfter,
  }) {
    if (createdAt is! Timestamp || senderId == userId) return false;

    return createdAt.seconds > unreadAfter.seconds ||
        (createdAt.seconds == unreadAfter.seconds &&
            createdAt.nanoseconds > unreadAfter.nanoseconds);
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> chatReadDocument({
    required String gubId,
    required String userId,
  }) {
    return _firestore
        .collection("gubs")
        .doc(gubId)
        .collection("chatReads")
        .doc(userId);
  }

  Future<void> markAsRead({
    required String gubId,
    required String userId,
  }) async {
    await GubRepository.instance.ensureActive(gubId);
    return chatReadDocument(gubId: gubId, userId: userId).set({
      "userId": userId,
      "gubId": gubId,
      "lastReadAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<int> unreadCountStream({
    required String gubId,
    required String userId,
    required Timestamp membershipBoundary,
  }) {
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    readSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    messagesSubscription;

    var queryGeneration = 0;
    var hasReadState = false;
    Timestamp? activeLastReadAt;

    late final StreamController<int> controller;

    bool sameTimestamp(Timestamp? first, Timestamp? second) {
      if (first == null || second == null) return first == second;

      return first.seconds == second.seconds &&
          first.nanoseconds == second.nanoseconds;
    }

    Future<void> replaceMessagesQuery(Timestamp? lastReadAt) async {
      final generation = ++queryGeneration;

      await messagesSubscription?.cancel();
      if (controller.isClosed || generation != queryGeneration) return;

      Query<Map<String, dynamic>> query = _firestore
          .collection("gubs")
          .doc(gubId)
          .collection("messages")
          .orderBy("createdAt");

      query = query.where(
        "createdAt",
        isGreaterThan: effectiveUnreadAfter(
          membershipBoundary: membershipBoundary,
          lastReadAt: lastReadAt,
        ),
      );

      messagesSubscription = query.snapshots().listen(
        (snapshot) {
          if (controller.isClosed || generation != queryGeneration) return;

          var unreadCount = 0;

          for (final document in snapshot.docs) {
            final data = document.data();
            final createdAt = data["createdAt"];
            final senderId = data["senderId"];

            if (shouldCountUnreadMessage(
              createdAt: createdAt,
              senderId: senderId,
              userId: userId,
              unreadAfter: effectiveUnreadAfter(
                membershipBoundary: membershipBoundary,
                lastReadAt: lastReadAt,
              ),
            )) {
              unreadCount++;
            }
          }

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
        unawaited(replaceMessagesQuery(null));
        return;
      }

      final lastReadAt = snapshot.data()?["lastReadAt"];

      // A server timestamp is temporarily null while Firestore resolves it.
      // Keep the current query until the real Timestamp is available.
      if (lastReadAt is! Timestamp) return;

      if (hasReadState && sameTimestamp(activeLastReadAt, lastReadAt)) {
        return;
      }

      hasReadState = true;
      activeLastReadAt = lastReadAt;
      unawaited(replaceMessagesQuery(lastReadAt));
    }

    controller = StreamController<int>(
      onListen: () {
        readSubscription = chatReadDocument(gubId: gubId, userId: userId)
            .snapshots()
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
        await messagesSubscription?.cancel();
      },
    );

    return controller.stream;
  }
}
