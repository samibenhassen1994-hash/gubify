import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/chat/models/chat_message_model.dart';
import 'package:gubify/modules/chat/widgets/chat_message_bubble.dart';
import 'package:gubify/modules/community/models/community_chat_message_model.dart';
import 'package:gubify/modules/community/widgets/community_chat_message_bubble.dart';
import 'package:gubify/modules/chat/widgets/deleted_user_identity_builder.dart';
import 'package:gubify/repositories/user_repository.dart';
import 'package:gubify/modules/tasks/widgets/task_assignee_tile.dart';

void main() {
  test('repeated messages for one UID reuse one identity stream', () {
    final cache = UserExistenceStreamCache();
    var creations = 0;
    Stream<bool> create() {
      creations++;
      return Stream<bool>.value(true).asBroadcastStream();
    }

    final first = cache.forUser('sender', create);
    final second = cache.forUser('sender', create);

    expect(identical(first, second), isTrue);
    expect(creations, 1);
  });

  test('current-name renderers reuse one identity stream for the same UID', () {
    final cache = UserIdentityStreamCache();
    var creations = 0;
    Stream<UserIdentity> create() {
      creations++;
      return Stream<UserIdentity>.empty().asBroadcastStream();
    }

    final first = cache.forUser('member', create);
    final second = cache.forUser('member', create);

    expect(identical(first, second), isTrue);
    expect(creations, 1);
  });

  testWidgets('missing profile hides stale name and disables profile action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(
            message: _message,
            isCurrentUser: false,
            profileExists: Stream<bool>.value(false),
            onAvatarTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Deleted user'), findsOneWidget);
    expect(find.text('Former Name'), findsNothing);
    expect(find.text('Shared message remains'), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
    expect(taps, 0);
  });

  testWidgets('existing profile preserves identity and profile action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(
            message: _message,
            isCurrentUser: false,
            profileExists: Stream<bool>.value(true),
            onAvatarTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Former Name'), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    expect(taps, 1);
  });

  testWidgets('Community chat uses the same deleted-user identity policy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityChatMessageBubble(
            message: CommunityChatMessageModel(
              messageId: 'community-message',
              communityId: 'community',
              senderId: 'sender',
              senderName: 'Former Name',
              text: 'Community history remains',
              createdAt: Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
            ),
            isCurrentUser: false,
            profileExists: Stream<bool>.value(false),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Deleted user'), findsOneWidget);
    expect(find.text('Former Name'), findsNothing);
    expect(find.text('Community history remains'), findsOneWidget);
  });

  testWidgets(
    'Task assignee uses the canonical name and follows live updates',
    (tester) async {
      final identities = StreamController<UserIdentity>.broadcast(sync: true);
      addTearDown(identities.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskAssigneeTile(
              assignedUserId: 'user-a',
              assignedUserName: 'Old Name',
              identity: identities.stream,
            ),
          ),
        ),
      );

      expect(find.text('Old Name'), findsOneWidget);

      identities.add(const UserIdentity.existing('New Name'));
      await tester.pump();
      expect(find.text('New Name'), findsOneWidget);

      identities.add(const UserIdentity.existing('Newest Name'));
      await tester.pump();
      expect(find.text('Newest Name'), findsOneWidget);
    },
  );

  testWidgets(
    'organized-event and Shared Budget identity renderers prefer canonical names',
    (tester) async {
      final identities = StreamController<UserIdentity>.broadcast(sync: true);
      addTearDown(identities.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                _CurrentIdentityName(
                  userId: 'event-member',
                  fallbackName: 'Old event name',
                  identity: identities.stream,
                ),
                _CurrentIdentityName(
                  userId: 'budget-member',
                  fallbackName: 'Old budget name',
                  identity: identities.stream,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Old event name'), findsOneWidget);
      expect(find.text('Old budget name'), findsOneWidget);

      identities.add(const UserIdentity.existing('Current Name'));
      await tester.pump();
      expect(find.text('Current Name'), findsNWidgets(2));
    },
  );

  testWidgets('current identity falls back while loading or after an error', (
    tester,
  ) async {
    final identities = StreamController<UserIdentity>.broadcast(sync: true);
    addTearDown(identities.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _CurrentIdentityName(
            userId: 'user-a',
            fallbackName: 'Snapshot Name',
            identity: identities.stream,
          ),
        ),
      ),
    );

    expect(find.text('Snapshot Name'), findsOneWidget);

    identities.add(const UserIdentity.existing('Canonical Name'));
    await tester.pump();
    expect(find.text('Canonical Name'), findsOneWidget);

    identities.addError(StateError('temporary failure'));
    await tester.pump();
    expect(find.text('Snapshot Name'), findsOneWidget);
  });

  testWidgets('deleted identity never exposes its stored snapshot', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: _CurrentIdentityName(
            userId: '__deleted_user__',
            fallbackName: 'Former Name',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Deleted user'), findsOneWidget);
    expect(find.text('Former Name'), findsNothing);
  });
}

class _CurrentIdentityName extends StatelessWidget {
  const _CurrentIdentityName({
    required this.userId,
    required this.fallbackName,
    this.identity,
  });

  final String userId;
  final String fallbackName;
  final Stream<UserIdentity>? identity;

  @override
  Widget build(BuildContext context) {
    return DeletedUserIdentityBuilder(
      userId: userId,
      currentDisplayName: fallbackName,
      identity: identity,
      resolveCurrentDisplayName: true,
      builder: (context, displayName, deleted) => Text(displayName),
    );
  }
}

final _message = ChatMessageModel(
  messageId: 'message',
  gubId: 'gub',
  senderId: 'sender',
  senderName: 'Former Name',
  text: 'Shared message remains',
  createdAt: Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
);
