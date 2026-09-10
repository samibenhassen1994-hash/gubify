import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/guidelines/community_guidelines_gate.dart';
import 'package:gubify/modules/community/guidelines/community_guidelines_service.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/widgets/community_home_content.dart';

const _community = CommunityModel(
  communityId: 'community-1',
  name: 'Community',
  ownerId: 'owner-1',
  memberCount: 2,
  visibility: CommunityModel.publicVisibility,
  createdAt: null,
  type: CommunityModel.defaultType,
  language: CommunityModel.defaultLanguage,
  description: '',
  accessMode: CommunityModel.openAccessMode,
);

void main() {
  testWidgets('unaccepted member sees Guidelines before Community content', (
    tester,
  ) async {
    final service = _service(accepted: false);

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityGuidelinesGate(
          communityId: 'community-1',
          service: service,
          child: const CommunityHomeContent(
            community: _community,
            isKeyboardOpen: false,
            isOwner: false,
            chatView: SizedBox(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CommunityHomeContent), findsNothing);
    expect(find.byKey(const Key('community-guidelines-pages')), findsOneWidget);
  });

  testWidgets('accepted owner reaches the existing Community content', (
    tester,
  ) async {
    final service = _service(accepted: true);

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityGuidelinesGate(
          communityId: 'community-1',
          service: service,
          child: const Text('Community content'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Community content'), findsOneWidget);
    expect(find.byKey(const Key('community-guidelines-pages')), findsNothing);
  });

  testWidgets('successful acceptance reveals content on the same route', (
    tester,
  ) async {
    var writes = 0;
    var accepted = false;
    final service = CommunityGuidelinesService.forTesting(
      currentUserId: () => 'member-1',
      hasAccepted: ({required communityId, required userId}) async => accepted,
      accept: ({required communityId, required userId}) async {
        writes++;
        accepted = true;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityGuidelinesGate(
          communityId: 'community-1',
          service: service,
          child: const Text('Community content'),
        ),
      ),
    );
    await tester.pump();
    await _showFinalPage(tester);
    await tester.tap(find.byKey(const Key('community-guidelines-checkbox')));
    await tester.pump();
    await tester.tap(find.text('I understand and continue'));
    await tester.pump();

    expect(writes, 1);
    expect(find.text('Community content'), findsOneWidget);
  });

  testWidgets('failed acceptance stays gated and can be retried', (
    tester,
  ) async {
    var attempts = 0;
    final service = CommunityGuidelinesService.forTesting(
      currentUserId: () => 'member-1',
      hasAccepted: ({required communityId, required userId}) async => false,
      accept: ({required communityId, required userId}) async {
        attempts++;
        if (attempts == 1) throw StateError('offline');
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityGuidelinesGate(
          communityId: 'community-1',
          service: service,
          child: const Text('Community content'),
        ),
      ),
    );
    await tester.pump();
    await _showFinalPage(tester);
    await tester.tap(find.byKey(const Key('community-guidelines-checkbox')));
    await tester.pump();

    await tester.tap(find.text('I understand and continue'));
    await tester.pump();
    expect(find.text('Community content'), findsNothing);
    expect(
      find.text('Unable to save your acceptance. Please try again.'),
      findsOneWidget,
    );

    await tester.tap(find.text('I understand and continue'));
    await tester.pump();
    expect(attempts, 2);
    expect(find.text('Community content'), findsOneWidget);
  });
}

CommunityGuidelinesService _service({required bool accepted}) {
  return CommunityGuidelinesService.forTesting(
    currentUserId: () => 'member-1',
    hasAccepted: ({required communityId, required userId}) async => accepted,
    accept: ({required communityId, required userId}) async {},
  );
}

Future<void> _showFinalPage(WidgetTester tester) async {
  final pageView = tester.widget<PageView>(
    find.byKey(const Key('community-guidelines-pages')),
  );
  pageView.controller!.jumpToPage(4);
  await tester.pump();
}
