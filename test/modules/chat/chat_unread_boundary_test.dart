import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/chat/repositories/chat_read_repository.dart';

void main() {
  final memberId = 'member';
  final otherMemberId = 'other-member';
  final initialJoin = Timestamp.fromDate(DateTime.utc(2026, 1, 3));
  final rejoin = Timestamp.fromDate(DateTime.utc(2026, 1, 6));

  Timestamp at(int day) => Timestamp.fromDate(DateTime.utc(2026, 1, day));

  bool isUnread({
    required Timestamp createdAt,
    required String senderId,
    required Timestamp unreadAfter,
  }) => ChatReadRepository.shouldCountUnreadMessage(
    createdAt: createdAt,
    senderId: senderId,
    userId: memberId,
    unreadAfter: unreadAfter,
  );

  group('Private Chat unread membership boundary', () {
    test('a new member has no unread messages from before joining', () {
      final unreadAfter = ChatReadRepository.effectiveUnreadAfter(
        membershipBoundary: initialJoin,
      );

      expect(
        isUnread(
          createdAt: at(2),
          senderId: otherMemberId,
          unreadAfter: unreadAfter,
        ),
        isFalse,
      );
    });

    test('a post-join message from another member is unread', () {
      expect(
        isUnread(
          createdAt: at(4),
          senderId: otherMemberId,
          unreadAfter: initialJoin,
        ),
        isTrue,
      );
    });

    test('a current user message is not unread', () {
      expect(
        isUnread(
          createdAt: at(4),
          senderId: memberId,
          unreadAfter: initialJoin,
        ),
        isFalse,
      );
    });

    test(
      'a last read timestamp before joining cannot move the boundary back',
      () {
        expect(
          ChatReadRepository.effectiveUnreadAfter(
            membershipBoundary: initialJoin,
            lastReadAt: at(2),
          ),
          initialJoin,
        );
      },
    );

    test('a last read timestamp after joining becomes the boundary', () {
      final lastReadAt = at(4);
      expect(
        ChatReadRepository.effectiveUnreadAfter(
          membershipBoundary: initialJoin,
          lastReadAt: lastReadAt,
        ),
        lastReadAt,
      );
    });

    test(
      'a rejoin ignores a last read timestamp from the previous membership',
      () {
        expect(
          ChatReadRepository.effectiveUnreadAfter(
            membershipBoundary: rejoin,
            lastReadAt: at(4),
          ),
          rejoin,
        );
      },
    );

    test(
      'a message sent while the member was away is not unread after rejoin',
      () {
        expect(
          isUnread(
            createdAt: at(5),
            senderId: otherMemberId,
            unreadAfter: rejoin,
          ),
          isFalse,
        );
      },
    );

    test('a message sent after rejoin is unread', () {
      expect(
        isUnread(
          createdAt: at(7),
          senderId: otherMemberId,
          unreadAfter: rejoin,
        ),
        isTrue,
      );
    });

    test('mark-as-read clears unread without going below joinedAt', () {
      final lastReadAt = at(5);
      final unreadAfter = ChatReadRepository.effectiveUnreadAfter(
        membershipBoundary: initialJoin,
        lastReadAt: lastReadAt,
      );

      expect(unreadAfter, lastReadAt);
      expect(
        isUnread(
          createdAt: at(5),
          senderId: otherMemberId,
          unreadAfter: unreadAfter,
        ),
        isFalse,
      );
      expect(
        isUnread(
          createdAt: at(3),
          senderId: otherMemberId,
          unreadAfter: unreadAfter,
        ),
        isFalse,
      );
    });
  });
}
