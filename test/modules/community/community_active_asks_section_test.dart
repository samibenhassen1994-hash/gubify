import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/widgets/community_active_asks_section.dart';

CommunityAskModel _ask({
  required String id,
  required String authorId,
  CommunityAskType type = CommunityAskType.help,
}) => CommunityAskModel(
  askId: id,
  communityId: 'community-1',
  authorId: authorId,
  authorDisplayName: 'Sami',
  type: type,
  sourceMessageId: id,
  text: 'Preview for $id',
  createdAt: Timestamp.fromDate(DateTime(2026, 8, 28)),
  status: CommunityAskStatus.active,
);

void main() {
  testWidgets('shows active asks as simple non-clickable cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityActiveAsksSection(
            communityId: 'community-1',
            authorId: 'author-1',
            asksStream: Stream.value([
              _ask(id: 'message-1', authorId: 'author-1'),
              _ask(
                id: 'message-2',
                authorId: 'author-1',
                type: CommunityAskType.advice,
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active asks'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Advice'), findsOneWidget);
    expect(find.text('Preview for message-1'), findsOneWidget);
    expect(find.text('Active'), findsNWidgets(2));
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('shows a stable empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityActiveAsksSection(
            communityId: 'community-1',
            authorId: 'author-1',
            asksStream: Stream.value(const []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active asks'), findsOneWidget);
    expect(find.text('No active asks.'), findsOneWidget);
  });
}
