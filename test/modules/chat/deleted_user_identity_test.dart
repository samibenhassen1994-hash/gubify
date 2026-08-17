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

  test(
    'current-name renderers reuse one identity stream for the same UID',
    () async {
      final cache = UserIdentityStreamCache();
      var creations = 0;
      Stream<UserIdentity> create() {
        creations++;
        return Stream<UserIdentity>.empty().asBroadcastStream();
      }

      final first = cache.forUser('member', create);
      final second = cache.forUser('member', create);

      expect(identical(first, second), isTrue);
      expect(creations, 0);

      final subscription = first.listen((_) {});
      expect(creations, 1);
      await subscription.cancel();
      cache.clear();
    },
  );

  test(
    'identity cache replays the latest name after a listener closes',
    () async {
      final cache = UserIdentityStreamCache();
      final source = StreamController<UserIdentity>.broadcast(sync: true);
      var sourceCreations = 0;
      final stream = cache.forUser('user-a', () {
        sourceCreations++;
        return source.stream;
      });

      final firstValues = <UserIdentity>[];
      final firstSubscription = stream.listen(firstValues.add);
      source.add(const UserIdentity.existing('Old Name'));
      source.add(const UserIdentity.existing('New Name'));
      await Future<void>.delayed(Duration.zero);

      expect(firstValues, [
        const UserIdentity.existing('Old Name'),
        const UserIdentity.existing('New Name'),
      ]);

      await firstSubscription.cancel();

      final secondValues = <UserIdentity>[];
      final secondSubscription = stream.listen(secondValues.add);
      await Future<void>.delayed(Duration.zero);

      expect(secondValues, [const UserIdentity.existing('New Name')]);
      expect(sourceCreations, 1);

      await secondSubscription.cancel();
      cache.clear();
      await source.close();
    },
  );

  test(
    'identity cache shares one source and replays missing identities',
    () async {
      final cache = UserIdentityStreamCache();
      final source = StreamController<UserIdentity>.broadcast(sync: true);
      var sourceCreations = 0;
      final stream = cache.forUser('deleted-user', () {
        sourceCreations++;
        return source.stream;
      });

      final subscriptions = <StreamSubscription<UserIdentity>>[];
      for (var index = 0; index < 10; index++) {
        subscriptions.add(stream.listen((_) {}));
      }
      expect(sourceCreations, 1);

      source.add(const UserIdentity.missing());
      await Future<void>.delayed(Duration.zero);
      await Future.wait(
        subscriptions.map((subscription) => subscription.cancel()),
      );

      final reopenedValues = <UserIdentity>[];
      final reopenedSubscription = stream.listen(reopenedValues.add);
      await Future<void>.delayed(Duration.zero);

      expect(reopenedValues, [const UserIdentity.missing()]);
      expect(sourceCreations, 1);

      await reopenedSubscription.cancel();
      cache.clear();
      await source.close();
    },
  );

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
            identity: Stream<UserIdentity>.value(const UserIdentity.missing()),
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
            identity: Stream<UserIdentity>.value(
              const UserIdentity.existing('Former Name'),
            ),
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
            identity: Stream<UserIdentity>.value(const UserIdentity.missing()),
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
    'Private Chat uses canonical sender names and follows live rename',
    (tester) async {
      final identities = StreamController<UserIdentity>.broadcast(sync: true);
      addTearDown(identities.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              message: _message,
              isCurrentUser: false,
              identity: identities.stream,
            ),
          ),
        ),
      );

      expect(find.text('Former Name'), findsOneWidget);

      identities.add(const UserIdentity.existing('New Name'));
      await tester.pump();
      expect(find.text('New Name'), findsOneWidget);

      identities.add(const UserIdentity.existing('Newest Name'));
      await tester.pump();
      expect(find.text('Newest Name'), findsOneWidget);
    },
  );

  testWidgets(
    'Community Chat uses canonical sender names and follows live rename',
    (tester) async {
      final identities = StreamController<UserIdentity>.broadcast(sync: true);
      addTearDown(identities.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityChatMessageBubble(
              message: _communityMessage,
              isCurrentUser: false,
              identity: identities.stream,
            ),
          ),
        ),
      );

      expect(find.text('Former Name'), findsOneWidget);

      identities.add(const UserIdentity.existing('New Name'));
      await tester.pump();
      expect(find.text('New Name'), findsOneWidget);

      identities.add(const UserIdentity.existing('Newest Name'));
      await tester.pump();
      expect(find.text('Newest Name'), findsOneWidget);
    },
  );

  testWidgets(
    'both Chat bubbles use snapshot names while identity is loading',
    (tester) async {
      final identities = StreamController<UserIdentity>.broadcast(sync: true);
      addTearDown(identities.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ChatMessageBubble(
                  message: _message,
                  isCurrentUser: false,
                  identity: identities.stream,
                ),
                CommunityChatMessageBubble(
                  message: _communityMessage,
                  isCurrentUser: false,
                  identity: identities.stream,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Former Name'), findsNWidgets(2));
    },
  );

  testWidgets(
    'snapshot name is retained while a resolve-disabled identity waits',
    (tester) async {
      final profileExists = StreamController<bool>.broadcast(sync: true);
      addTearDown(profileExists.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _CurrentIdentityName(
              userId: 'source-author',
              fallbackName: 'Sami',
              profileExists: profileExists.stream,
              resolveCurrentDisplayName: false,
            ),
          ),
        ),
      );

      expect(find.text('Sami'), findsOneWidget);
      expect(find.text('User'), findsNothing);
    },
  );

  testWidgets('source-chat identities prefer canonical names after loading', (
    tester,
  ) async {
    final identities = StreamController<UserIdentity>.broadcast(sync: true);
    addTearDown(identities.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              _CurrentIdentityName(
                userId: 'task-source-author',
                fallbackName: 'Old task source name',
                identity: identities.stream,
              ),
              _CurrentIdentityName(
                userId: 'event-source-author',
                fallbackName: 'Old event source name',
                identity: identities.stream,
              ),
              _CurrentIdentityName(
                userId: 'budget-source-author',
                fallbackName: 'Old budget source name',
                identity: identities.stream,
              ),
              _CurrentIdentityName(
                userId: 'proposal-source-author',
                fallbackName: 'Old proposal source name',
                identity: identities.stream,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Old task source name'), findsOneWidget);
    expect(find.text('Old event source name'), findsOneWidget);
    expect(find.text('Old budget source name'), findsOneWidget);
    expect(find.text('Old proposal source name'), findsOneWidget);

    identities.add(const UserIdentity.existing('Renamed Sami'));
    await tester.pump();

    expect(find.text('Renamed Sami'), findsNWidgets(4));
  });

  testWidgets(
    'source-chat missing profiles render Deleted user in every module',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Task source: confirmed missing profiles must not expose the
                // historical snapshot.
                _CurrentIdentityName(
                  userId: 'task-source-author',
                  fallbackName: 'Old task source name',
                  identity: Stream<UserIdentity>.value(
                    const UserIdentity.missing(),
                  ),
                ),
                _CurrentIdentityName(
                  userId: 'event-source-author',
                  fallbackName: 'Old event source name',
                  identity: Stream<UserIdentity>.value(
                    const UserIdentity.missing(),
                  ),
                ),
                _CurrentIdentityName(
                  userId: 'budget-source-author',
                  fallbackName: 'Old budget source name',
                  identity: Stream<UserIdentity>.value(
                    const UserIdentity.missing(),
                  ),
                ),
                _CurrentIdentityName(
                  userId: 'proposal-source-author',
                  fallbackName: 'Old proposal source name',
                  identity: Stream<UserIdentity>.value(
                    const UserIdentity.missing(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Deleted user'), findsNWidgets(4));
      expect(find.text('Old task source name'), findsNothing);
      expect(find.text('Old event source name'), findsNothing);
      expect(find.text('Old budget source name'), findsNothing);
      expect(find.text('Old proposal source name'), findsNothing);
    },
  );

  testWidgets('source-chat deleted sentinels bypass identity lookups', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              _CurrentIdentityName(
                userId: '__deleted_user__',
                fallbackName: 'Former task source name',
              ),
              _CurrentIdentityName(
                userId: '__deleted_user__',
                fallbackName: 'Former event source name',
              ),
              _CurrentIdentityName(
                userId: '__deleted_user__',
                fallbackName: 'Former budget source name',
              ),
              _CurrentIdentityName(
                userId: '__deleted_user__',
                fallbackName: 'Former proposal source name',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Deleted user'), findsNWidgets(4));
    expect(find.textContaining('Former'), findsNothing);
  });

  testWidgets('source-chat legacy records retain snapshots without lookups', (
    tester,
  ) async {
    var lookupSubscriptions = 0;
    final neverUsedIdentity = Stream<UserIdentity>.multi((controller) {
      lookupSubscriptions++;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              _CurrentIdentityName(
                userId: '',
                fallbackName: 'Legacy task source name',
                identity: neverUsedIdentity,
              ),
              const _CurrentIdentityName(
                userId: '',
                fallbackName: 'Legacy event source name',
              ),
              const _CurrentIdentityName(
                userId: '',
                fallbackName: 'Legacy budget source name',
              ),
              const _CurrentIdentityName(
                userId: '',
                fallbackName: 'Legacy proposal source name',
              ),
              const _CurrentIdentityName(userId: '', fallbackName: ''),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(lookupSubscriptions, 0);
    expect(find.text('Legacy task source name'), findsOneWidget);
    expect(find.text('Legacy event source name'), findsOneWidget);
    expect(find.text('Legacy budget source name'), findsOneWidget);
    expect(find.text('Legacy proposal source name'), findsOneWidget);
    expect(find.text('User'), findsOneWidget);
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
    this.profileExists,
    this.resolveCurrentDisplayName = true,
  });

  final String userId;
  final String fallbackName;
  final Stream<UserIdentity>? identity;
  final Stream<bool>? profileExists;
  final bool resolveCurrentDisplayName;

  @override
  Widget build(BuildContext context) {
    return DeletedUserIdentityBuilder(
      userId: userId,
      currentDisplayName: fallbackName,
      identity: identity,
      profileExists: profileExists,
      resolveCurrentDisplayName: resolveCurrentDisplayName,
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

final _communityMessage = CommunityChatMessageModel(
  messageId: 'community-message',
  communityId: 'community',
  senderId: 'sender',
  senderName: 'Former Name',
  text: 'Community history remains',
  createdAt: Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
);
