import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/notifications/models/notification_model.dart';
import 'package:gubify/modules/notifications/repositories/notification_repository.dart';

void main() {
  const memberId = 'member';
  const otherMemberId = 'other-member';
  final initialJoin = Timestamp.fromDate(DateTime.utc(2026, 1, 3));
  final rejoin = Timestamp.fromDate(DateTime.utc(2026, 1, 6));

  Timestamp at(int day) => Timestamp.fromDate(DateTime.utc(2026, 1, day));

  NotificationModel notification({
    required String id,
    required Timestamp createdAt,
    String senderId = otherMemberId,
    List<String> readBy = const [],
  }) {
    return NotificationModel(
      notificationId: id,
      title: id,
      body: id,
      type: 'task_created',
      senderId: senderId,
      senderName: senderId,
      createdAt: createdAt,
      readBy: readBy,
      data: const {},
    );
  }

  bool isUnread(
    NotificationModel value, {
    required Timestamp membershipBoundary,
  }) {
    return NotificationRepository.shouldCountUnreadNotification(
      notification: value,
      userId: memberId,
      membershipBoundary: membershipBoundary,
    );
  }

  group('Private Gub notification unread membership boundary', () {
    test('Board notifications stay outside the general notification flow', () {
      final boardNotification = NotificationModel(
        notificationId: 'board',
        title: 'New Board post',
        body: 'A post',
        type: 'board_post',
        senderId: otherMemberId,
        senderName: 'Other member',
        createdAt: at(7),
        readBy: const [],
        data: const {},
      );

      expect(
        NotificationRepository.isGeneralNotification(boardNotification),
        isFalse,
      );
      expect(isUnread(boardNotification, membershipBoundary: rejoin), isFalse);
    });

    test('a new member has no unread notifications from before joining', () {
      expect(
        isUnread(
          notification(id: 'pre-join', createdAt: at(2)),
          membershipBoundary: initialJoin,
        ),
        isFalse,
      );
    });

    test('a post-join notification from another member is unread', () {
      expect(
        isUnread(
          notification(id: 'post-join', createdAt: at(4)),
          membershipBoundary: initialJoin,
        ),
        isTrue,
      );
    });

    test('marking a notification as read clears it from the badge', () {
      expect(
        isUnread(
          notification(id: 'read', createdAt: at(4), readBy: const [memberId]),
          membershipBoundary: initialJoin,
        ),
        isFalse,
      );
    });

    test('the current user notification does not increment the badge', () {
      expect(
        isUnread(
          notification(id: 'own', createdAt: at(4), senderId: memberId),
          membershipBoundary: initialJoin,
        ),
        isFalse,
      );
    });

    test(
      'a rejoin hides unread notifications from the previous membership',
      () {
        expect(
          isUnread(
            notification(id: 'previous', createdAt: at(4)),
            membershipBoundary: rejoin,
          ),
          isFalse,
        );
      },
    );

    test('a notification sent while away is not unread after rejoin', () {
      expect(
        isUnread(
          notification(id: 'while-away', createdAt: at(5)),
          membershipBoundary: rejoin,
        ),
        isFalse,
      );
    });

    test('a notification after rejoin is unread', () {
      expect(
        isUnread(
          notification(id: 'post-rejoin', createdAt: at(7)),
          membershipBoundary: rejoin,
        ),
        isTrue,
      );
    });

    test('recipient filtering still prevents unrelated badge entries', () {
      final targetedElsewhere = NotificationModel(
        notificationId: 'other-recipient',
        title: 'Other recipient',
        body: 'Other recipient',
        type: 'task_created',
        senderId: otherMemberId,
        senderName: otherMemberId,
        createdAt: at(7),
        readBy: const [],
        data: const {
          'recipientIds': ['another-member'],
        },
      );

      expect(isUnread(targetedElsewhere, membershipBoundary: rejoin), isFalse);
    });
  });
}
