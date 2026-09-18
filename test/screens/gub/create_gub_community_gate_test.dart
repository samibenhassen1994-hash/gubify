import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/screens/gub/create_gub_screen.dart';
import 'package:gubify/modules/community/models/community_model.dart';

void main() {
  testWidgets('shell-managed private creation reports the new Gub id', (
    tester,
  ) async {
    String? createdGubId;
    await tester.pumpWidget(
      MaterialApp(
        home: CreateGubScreen(
          userHeader: const SizedBox.shrink(),
          privateGubCreator: ({required name}) async => 'created-gub',
          onPrivateGubCreated: (gubId) => createdGubId = gubId,
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'New private Gub');
    await tester.ensureVisible(find.text('Create private Gub'));
    await tester.tap(find.text('Create private Gub'));
    await tester.pumpAndSettle();

    expect(createdGubId, 'created-gub');
    expect(find.text('New private Gub'), findsOneWidget);
  });

  testWidgets('shell-managed Community creation reports the Community', (
    tester,
  ) async {
    CommunityModel? createdCommunity;
    await tester.pumpWidget(
      MaterialApp(
        home: CreateGubScreen(
          userHeader: const SizedBox.shrink(),
          communityLinkedAccountGate: (_) async => true,
          currentUserOwnsCommunity: () async => false,
          communityGuidelinesPreAction: (_) async => true,
          communityCreator:
              ({
                required name,
                required description,
                required type,
                required language,
                required accessMode,
              }) async => CommunityModel(
                communityId: 'created-community',
                name: name,
                ownerId: 'owner',
                memberCount: 1,
                visibility: CommunityModel.publicVisibility,
                createdAt: null,
                type: type,
                language: language,
                description: description,
                accessMode: accessMode,
              ),
          onCommunityCreated: (community) => createdCommunity = community,
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Community'));
    await tester.tap(find.text('Community'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'New Community');
    await tester.ensureVisible(find.text('Create community'));
    await tester.tap(find.text('Create community'));
    await tester.pumpAndSettle();

    expect(createdCommunity?.communityId, 'created-community');
    expect(find.text('New Community'), findsOneWidget);
  });

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
