import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/screens/gub/create_gub_screen.dart';
import 'package:gubify/modules/community/models/community_model.dart';

void main() {
  testWidgets(
    'Community selection stays Private when account gate is cancelled',
    (tester) async {
      var gateCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CreateGubScreen(
            userHeader: const SizedBox.shrink(),
            communityLinkedAccountGate: (_) async {
              gateCalls++;
              return false;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Community'));
      await tester.tap(find.text('Community'));
      await tester.pumpAndSettle();

      expect(gateCalls, 1);
      expect(find.text('Create private Gub'), findsOneWidget);
      expect(find.text('Create community'), findsNothing);
    },
  );

  testWidgets('Community creation waits for Guidelines acceptance', (
    tester,
  ) async {
    var creates = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CreateGubScreen(
          userHeader: const SizedBox.shrink(),
          communityLinkedAccountGate: (_) async => true,
          currentUserOwnsCommunity: () async => false,
          communityGuidelinesPreAction: (_) async => false,
          communityCreator:
              ({
                required name,
                required description,
                required type,
                required language,
                required accessMode,
              }) async {
                creates++;
                return const CommunityModel(
                  communityId: 'community',
                  name: 'Test Community',
                  ownerId: 'owner',
                  memberCount: 1,
                  visibility: CommunityModel.publicVisibility,
                  createdAt: null,
                  type: CommunityModel.defaultType,
                  language: CommunityModel.defaultLanguage,
                  description: '',
                  accessMode: CommunityModel.approvalAccessMode,
                );
              },
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Community'));
    await tester.tap(find.text('Community'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Test Community');
    await tester.ensureVisible(find.text('Create community'));
    await tester.tap(find.text('Create community'));
    await tester.pumpAndSettle();

    expect(creates, 0);
    expect(find.text('Test Community'), findsOneWidget);
  });
}
