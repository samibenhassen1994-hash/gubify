import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../repositories/chat_read_repository.dart';

class ChatReadService {
  ChatReadService._();

  static final ChatReadService instance = ChatReadService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<int> unreadCountStream(String gubId) {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream<int>.error(
        StateError("You must be signed in to read chat messages."),
      );
    }

    return Stream.fromFuture(_membershipBoundary(gubId, user.uid)).asyncExpand(
      (boundary) => boundary == null
          ? Stream.value(0)
          : ChatReadRepository.instance.unreadCountStream(
              gubId: gubId,
              userId: user.uid,
              membershipBoundary: boundary,
            ),
    );
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

  Future<Timestamp?> _membershipBoundary(String gubId, String userId) async {
    final membership = await _firestore
        .collection('gubs')
        .doc(gubId)
        .collection('members')
        .doc(userId)
        .get(const GetOptions(source: Source.server));
    final joinedAt = membership.data()?['joinedAt'];
    return membership.exists && joinedAt is Timestamp ? joinedAt : null;
  }
}
