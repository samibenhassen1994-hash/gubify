import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_chat_message_model.dart';
import 'package:gubify/modules/community/restrictions/models/community_restriction_model.dart';
import 'package:gubify/modules/community/widgets/community_chat_view.dart';

void main() {
  Widget chat({
    required PlatformRestriction restriction,
    VoidCallback? onSend,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CommunityChatView(
          communityId: 'community',
          messagesStream: Stream.value(const <CommunityChatMessageModel>[]),
          restrictionStream: Stream.value(restriction),
          onSend: (_) async => onSend?.call(),
        ),
      ),
    );
  }

  testWidgets(
    'restricted Community chat disables its composer with neutral copy',
    (tester) async {
      await tester.pumpWidget(
        chat(
          restriction: const PlatformRestriction(communityChatRestricted: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Community messaging is unavailable for this account.'),
        findsOneWidget,
      );
      expect(
        tester.widget<IconButton>(find.byType(IconButton).last).onPressed,
        isNull,
      );
    },
  );

  testWidgets('unrestricted Community chat keeps the composer available', (
    tester,
  ) async {
    var sends = 0;
    await tester.pumpWidget(
      chat(
        restriction: PlatformRestriction.unrestricted,
        onSend: () => sends++,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(
      find.text('Community messaging is unavailable for this account.'),
      findsNothing,
    );
    expect(sends, 1);
  });
}
