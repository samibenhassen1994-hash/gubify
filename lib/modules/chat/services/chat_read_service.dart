import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/gub_service.dart';
import '../repositories/chat_read_repository.dart';

class ChatReadService {
  ChatReadService._();

  static final ChatReadService instance = ChatReadService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<int> unreadCountStream(String gubId) {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream<int>.error(
        StateError("You must be signed in to read chat messages."),
      );
    }

    return _withMembershipBoundary(
      gubId,
      (boundary) => ChatReadRepository.instance.unreadCountStream(
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

  Future<void> markAsRead(String gubId) {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError("You must be signed in to update chat read status.");
    }

    return ChatReadRepository.instance.markAsRead(
      gubId: gubId,
      userId: user.uid,
    );
  }
}
