import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_chat_message_model.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/widgets/community_chat_message_bubble.dart';
import 'package:gubify/modules/community/widgets/community_ask_type_sheet.dart';
import 'package:gubify/repositories/user_repository.dart';

CommunityChatMessageModel _message({required String senderId}) =>
    CommunityChatMessageModel(
      messageId: 'message-1',
      communityId: 'community-1',
      senderId: senderId,
      senderName: 'Sami',
      text: 'Can someone help?',
      createdAt: Timestamp.fromMillisecondsSinceEpoch(1),
    );

void main() {
  testWidgets('own Community message exposes Create ask on long press', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityChatMessageBubble(
            message: _message(senderId: 'me'),
            isCurrentUser: true,
            identity: Stream.value(const UserIdentity.existing('Sami')),
            onCreateAsk: () => opened = true,
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Can someone help?'));
    await tester.pumpAndSettle();

    expect(find.text('Create ask'), findsOneWidget);
    expect(find.text('Report message'), findsNothing);
    await tester.tap(find.text('Create ask'));
    expect(opened, isTrue);
  });

  testWidgets('another user message exposes only Report message', (
    tester,
  ) async {
    var reported = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityChatMessageBubble(
            message: _message(senderId: 'other'),
            isCurrentUser: false,
            identity: Stream.value(const UserIdentity.existing('Sami')),
            onReportMessage: () => reported = true,
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Can someone help?'));
    await tester.pumpAndSettle();

    expect(find.text('Create ask'), findsNothing);
    expect(find.text('Report message'), findsOneWidget);
    await tester.tap(find.text('Report message'));
    await tester.pumpAndSettle();
    expect(reported, isTrue);
  });

  testWidgets('Community chat avatar renders the supplied shared XP level', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityChatMessageBubble(
            message: _message(senderId: 'other'),
            isCurrentUser: false,
            xp: 640,
            identity: Stream.value(const UserIdentity.existing('Sami')),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Lv 8'), findsOneWidget);
  });

  testWidgets(
    'Community message avatar and name open the existing profile flow',
    (tester) async {
      var profileOpens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityChatMessageBubble(
              message: _message(senderId: 'other'),
              isCurrentUser: false,
              identity: Stream.value(const UserIdentity.existing('Sami')),
              onProfileTap: () => profileOpens++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sami'));
      await tester.pump();
      expect(profileOpens, 1);

      await tester.tap(find.byType(CircleAvatar));
      await tester.pump();
      expect(profileOpens, 2);
    },
  );

  testWidgets('ask type sheet returns each stable category', (tester) async {
    CommunityAskType? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showCommunityAskTypeSheet(context);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    for (final entry in const [
      ('Help', CommunityAskType.help),
      ('Information', CommunityAskType.information),
      ('Advice', CommunityAskType.advice),
    ]) {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.$1));
      await tester.pumpAndSettle();
      expect(selected, entry.$2);
    }
  });
}
