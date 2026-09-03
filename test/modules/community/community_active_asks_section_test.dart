import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/widgets/community_active_asks_section.dart';
import 'package:gubify/widgets/gub_content_card.dart';

CommunityAskModel _ask({
  required String id,
  required String authorId,
  CommunityAskType type = CommunityAskType.help,
  CommunityAskStatus status = CommunityAskStatus.active,
}) => CommunityAskModel(
  askId: id,
  communityId: 'community-1',
  authorId: authorId,
  authorDisplayName: 'Sami',
  type: type,
  sourceMessageId: id,
  text: 'Preview for $id',
  createdAt: Timestamp.fromDate(DateTime(2026, 8, 28)),
  status: status,
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

    expect(find.text('Active Asks'), findsOneWidget);
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

    final title = find.text('Active Asks');
    final empty = find.text('No active Asks');
    expect(title, findsOneWidget);
    expect(empty, findsOneWidget);
    expect(
      find.ancestor(of: title, matching: find.byType(GubContentCard)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: empty, matching: find.byType(GubContentCard)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: title, matching: find.byType(Center)),
      findsOneWidget,
    );
  });

  testWidgets('profile active section excludes resolved asks', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityActiveAsksSection(
            communityId: 'community-1',
            authorId: 'author-1',
            asksStream: Stream.value([
              _ask(id: 'active', authorId: 'author-1'),
              _ask(
                id: 'resolved',
                authorId: 'author-1',
                status: CommunityAskStatus.resolved,
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview for active'), findsOneWidget);
    expect(find.text('Preview for resolved'), findsNothing);
  });
}
