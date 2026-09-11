import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/guidelines/community_guidelines_pre_action.dart';
import 'package:gubify/modules/community/guidelines/community_guidelines_service.dart';

void main() {
  testWidgets(
    'unaccepted user must explicitly accept before action continues',
    (tester) async {
      var accepted = false;
      var writes = 0;
      bool? result;
      final service = CommunityGuidelinesService.forTesting(
        currentUserId: () => 'user',
        hasAccepted: ({required userId}) async => accepted,
        accept: ({required userId}) async {
          writes++;
          accepted = true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await ensureCommunityGuidelinesAccepted(
                  context,
                  service: service,
                );
              },
              child: const Text('Continue'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('I understand and continue'), findsOneWidget);
      expect(writes, 0);

      await tester.tap(find.byKey(const Key('community-guidelines-checkbox')));
      await tester.pump();
      await tester.tap(find.text('I understand and continue'));
      await tester.pumpAndSettle();

      expect(writes, 1);
      expect(result, isTrue);
    },
  );

  testWidgets('backing out returns false without persisting acceptance', (
    tester,
  ) async {
    var writes = 0;
    bool? result;
    final service = CommunityGuidelinesService.forTesting(
      currentUserId: () => 'user',
      hasAccepted: ({required userId}) async => false,
      accept: ({required userId}) async => writes++,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await ensureCommunityGuidelinesAccepted(
                context,
                service: service,
              );
            },
            child: const Text('Continue'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('community-guidelines-back')));
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsOneWidget);
    expect(result, isFalse);
    expect(writes, 0);
  });

  testWidgets('current acceptance skips onboarding', (tester) async {
    var writes = 0;
    bool? result;
    final service = CommunityGuidelinesService.forTesting(
      currentUserId: () => 'user',
      hasAccepted: ({required userId}) async => true,
      accept: ({required userId}) async => writes++,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await ensureCommunityGuidelinesAccepted(
                context,
                service: service,
              );
            },
            child: const Text('Continue'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(writes, 0);
    expect(find.text('I understand and continue'), findsNothing);
  });
}
