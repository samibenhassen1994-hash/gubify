import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/moderation/blocking/models/user_block_model.dart';
import 'package:gubify/modules/moderation/blocking/utils/user_block_message_visibility.dart';

void main() {
  final blockedAt = Timestamp(100, 500);

  test('keeps messages visible when their sender is not blocked', () {
    expect(
      isUserBlockMessageVisible(
        senderId: 'other',
        createdAt: Timestamp(100, 500),
        blockedAtByUser: {'blocked': blockedAt},
      ),
      isTrue,
    );
  });

  test(
    'keeps a blocked sender message before the nanosecond cutoff visible',
    () {
      expect(
        isUserBlockMessageVisible(
          senderId: 'blocked',
          createdAt: Timestamp(100, 499),
          blockedAtByUser: {'blocked': blockedAt},
        ),
        isTrue,
      );
    },
  );

  test('hides a blocked sender message at or after the exact cutoff', () {
    final blocks = {'blocked': blockedAt};

    expect(
      isUserBlockMessageVisible(
        senderId: 'blocked',
        createdAt: Timestamp(100, 500),
        blockedAtByUser: blocks,
      ),
      isFalse,
    );
    expect(
      isUserBlockMessageVisible(
        senderId: 'blocked',
        createdAt: Timestamp(100, 501),
        blockedAtByUser: blocks,
      ),
      isFalse,
    );
  });

  test(
    'uses each blocked user cutoff independently and restores on unblock',
    () {
      final blocks = blockedAtByUser([
        UserBlockModel(blockedUserId: 'first', blockedAt: Timestamp(10, 0)),
        UserBlockModel(blockedUserId: 'second', blockedAt: Timestamp(20, 0)),
      ]);

      expect(
        isUserBlockMessageVisible(
          senderId: 'first',
          createdAt: Timestamp(15, 0),
          blockedAtByUser: blocks,
        ),
        isFalse,
      );
      expect(
        isUserBlockMessageVisible(
          senderId: 'second',
          createdAt: Timestamp(15, 0),
          blockedAtByUser: blocks,
        ),
        isTrue,
      );
      expect(
        isUserBlockMessageVisible(
          senderId: 'first',
          createdAt: Timestamp(15, 0),
          blockedAtByUser: const {},
        ),
        isTrue,
      );
    },
  );
}
