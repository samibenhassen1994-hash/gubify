import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/models/community_ask_answer_model.dart';
import 'package:gubify/modules/community/moderation/models/community_report_model.dart';
import 'package:gubify/modules/community/moderation/services/community_moderation_service.dart';
import 'package:gubify/modules/community/widgets/community_ask_card.dart';

final _ask = CommunityAskModel(
  askId: 'ask-1',
  communityId: 'community-1',
  authorId: 'author-1',
  authorDisplayName: 'Author',
  type: CommunityAskType.help,
  text: 'Ask content',
  createdAt: Timestamp(1, 0),
  status: CommunityAskStatus.active,
);

void main() {
  test('Ask and Answer moderation keys are content-specific', () {
    const ask = CommunityModerationReport(
      reportId: 'ask__community-1__ask-1__reporter',
      reporterId: 'reporter',
      communityId: 'community-1',
      targetType: 'ask',
      targetId: 'ask-1',
      reason: 'spam',
      details: '',
      communityNameSnapshot: 'Community',
      targetUserId: 'author-1',
      targetNameSnapshot: 'Author',
      contentSnapshot: 'Ask content',
    );
    const firstAnswer = CommunityModerationReport(
      reportId: 'answer__community-1__ask-1__author-1__reporter',
      reporterId: 'reporter',
      communityId: 'community-1',
      askId: 'ask-1',
      targetType: 'answer',
      targetId: 'author-1',
      reason: 'spam',
      details: '',
      communityNameSnapshot: 'Community',
      targetUserId: 'author-1',
      targetNameSnapshot: 'Author',
      contentSnapshot: 'Answer content',
    );
    const secondAnswer = CommunityModerationReport(
      reportId: 'answer__community-1__ask-2__author-1__reporter',
      reporterId: 'reporter',
      communityId: 'community-1',
      askId: 'ask-2',
      targetType: 'answer',
      targetId: 'author-1',
      reason: 'spam',
      details: '',
      communityNameSnapshot: 'Community',
      targetUserId: 'author-1',
      targetNameSnapshot: 'Author',
      contentSnapshot: 'Other answer content',
    );

    expect(ask.moderationTargetKey, 'ask__community-1__ask-1');
    expect(
      firstAnswer.moderationTargetKey,
      'answer__community-1__ask-1__author-1',
    );
    expect(
      secondAnswer.moderationTargetKey,
      isNot(firstAnswer.moderationTargetKey),
    );
  });

  test(
    'report service preserves Ask and Answer snapshots without Firebase',
    () async {
      final reports = <CommunityModerationReport>[];
      final service = CommunityModerationService.forTesting(
        currentUserId: () => 'reporter',
        createReport: (report) async {
          reports.add(report);
          return true;
        },
      );
      await service.reportAsk(
        ask: _ask,
        communityName: 'Community',
        reason: 'spam',
        details: ' details ',
      );
      await service.reportAnswer(
        ask: _ask,
        answer: CommunityAskAnswerModel(
          answerId: 'answer-1',
          authorId: 'answer-author',
          authorDisplayName: 'Answer Author',
          text: 'Answer content',
          createdAt: Timestamp(2, 0),
        ),
        communityName: 'Community',
        reason: 'spam',
        details: '',
      );
      expect(reports[0].reportId, 'ask__community-1__ask-1__reporter');
      expect(reports[0].contentSnapshot, 'Ask content');
      expect(reports[0].details, 'details');
      expect(
        reports[1].moderationTargetKey,
        'answer__community-1__ask-1__answer-1',
      );
      expect(reports[1].contentSnapshot, 'Answer content');
    },
  );

  testWidgets('long press reports another user Ask without changing tap', (
    tester,
  ) async {
    var opened = false;
    var reported = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityAskCard(
            ask: _ask,
            currentUserId: 'other-user',
            onTap: () => opened = true,
            onReport: () async => reported = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ask content'));
    expect(opened, isTrue);
    await tester.longPress(find.text('Ask content'));
    await tester.pumpAndSettle();
    expect(find.text('Report Ask'), findsOneWidget);
    await tester.tap(find.text('Report Ask'));
    await tester.pumpAndSettle();
    expect(reported, isTrue);
  });

  testWidgets('long press does not offer reporting an own Ask', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityAskCard(
            ask: _ask,
            currentUserId: 'author-1',
            onTap: _noop,
          ),
        ),
      ),
    );
    await tester.longPress(find.text('Ask content'));
    await tester.pumpAndSettle();
    expect(find.text('Report Ask'), findsNothing);
  });
}

void _noop() {}
