import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/models/community_ask_answer_model.dart';
import 'package:gubify/modules/community/screens/community_ask_details_screen.dart';
import 'package:gubify/modules/community/services/community_user_xp_cache.dart';
import 'package:gubify/modules/community/models/community_chat_message_model.dart';
import 'package:gubify/modules/community/widgets/community_ask_card.dart';
import 'package:gubify/modules/community/widgets/community_chat_message_bubble.dart';

void main() {
  testWidgets(
    'ordinary Ask cards replace hidden text while preserving status',
    (tester) async {
      final ask = CommunityAskModel.fromFirestore({
        'text': 'Sensitive original ask',
        'moderationHidden': true,
        'authorDisplayName': 'Author',
        'authorId': 'author',
        'createdAt': Timestamp(1, 0),
        'status': 'resolved',
      }, askId: 'a');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityAskCard(ask: ask, onTap: () {}, authorXp: 0),
          ),
        ),
      );
      expect(find.text('Sensitive original ask'), findsNothing);
      expect(find.text('Removed by moderation'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(ask.text, 'Sensitive original ask');
    },
  );
  testWidgets(
    'resolved thread hides moderated Best Answer while retaining best status',
    (tester) async {
      final ask = CommunityAskModel.fromFirestore({
        'communityId': 'c',
        'authorId': 'owner',
        'text': 'Question',
        'createdAt': Timestamp(1, 0),
        'status': 'resolved',
        'bestAnswerId': 'member',
        'bestAnswerAuthorId': 'member',
        'xpAwarded': true,
      }, askId: 'a');
      final answer = CommunityAskAnswerModel.fromFirestore({
        'authorId': 'member',
        'authorDisplayName': 'Member',
        'text': 'Sensitive original answer',
        'moderationHidden': true,
        'createdAt': Timestamp(2, 0),
      }, answerId: 'member');
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityAskDetailsScreen(
            ask: ask,
            communityName: 'Community',
            currentUserId: 'reader',
            askStream: Stream.value(ask),
            answersStream: Stream.value([answer]),
            membershipXpCache: CommunityUserXpCache(loadXp: (_) async => {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sensitive original answer'), findsNothing);
      expect(find.text('Removed by moderation'), findsOneWidget);
      expect(find.text('Best Answer'), findsOneWidget);
      expect(answer.text, 'Sensitive original answer');
      expect(ask.xpAwarded, true);
    },
  );
  testWidgets('ordinary chat hides moderated text and restores unhidden text', (
    tester,
  ) async {
    Future<void> render(bool hidden) async {
      final message = CommunityChatMessageModel.fromFirestore({
        'text': 'Sensitive original message',
        'moderationHidden': hidden,
        'senderId': 'author',
        'senderName': 'Author',
        'createdAt': Timestamp(1, 0),
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityChatMessageBubble(
              message: message,
              isCurrentUser: true,
              profileExists: Stream.value(true),
              xp: 0,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await render(true);
    expect(find.text('Sensitive original message'), findsNothing);
    expect(find.text('Removed by moderation'), findsOneWidget);
    await render(false);
    expect(find.text('Sensitive original message'), findsOneWidget);
    expect(find.text('Removed by moderation'), findsNothing);
  });
}
