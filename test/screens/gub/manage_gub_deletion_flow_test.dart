import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/profile/models/user_profile_model.dart';
import 'package:gubify/screens/gub/manage_gub_screen.dart';
import 'package:gubify/screens/main_navigation_shell.dart';
import 'package:gubify/services/gub_deletion_service.dart';
import 'package:gubify/widgets/gubify_bottom_navigation_bar.dart';

void main() {
  testWidgets(
    'Manage Gub confirms deletion once and returns through the shell callback',
    (tester) async {
      var deleteCalls = 0;
      var shellExits = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ManageGubScreen(
            gubId: 'gub-1',
            accessLoader: (_) async =>
                const GubDeletionAccess(isOwner: true, gubName: 'Private Gub'),
            deleteGub:
                ({
                  required gubId,
                  required confirmedName,
                  required onProgress,
                }) async {
                  deleteCalls += 1;
                  expect(gubId, 'gub-1');
                  expect(confirmedName, 'Private Gub');
                },
            onExitToMyGubs: () => shellExits += 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _completeDeletion(tester);

      expect(deleteCalls, 1);
      expect(shellExits, 1);
    },
  );

  testWidgets(
    'completed shell-managed deletion returns to the existing My Gubs shell',
    (tester) async {
      var deleteCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: MainNavigationShell(
            userId: 'owner-1',
            isAnonymous: false,
            currentUserProfile: Future.value(
              const UserProfileModel(
                userId: 'owner-1',
                displayName: 'Owner',
                isCurrentUser: true,
              ),
            ),
            homeBuilder: (_, _, _, _, _, _) =>
                const Scaffold(body: Text('Home root')),
            myGubsBuilder: (_, _) =>
                const Scaffold(body: Text('Shell My Gubs')),
            exploreBuilder: (_) => const SizedBox.shrink(),
            notificationsBuilder: (_) => const SizedBox.shrink(),
            profileBuilder: (_, onExitToMyGubs) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ManageGubScreen(
                        gubId: 'gub-1',
                        accessLoader: (_) async => const GubDeletionAccess(
                          isOwner: true,
                          gubName: 'Private Gub',
                        ),
                        deleteGub:
                            ({
                              required gubId,
                              required confirmedName,
                              required onProgress,
                            }) async {
                              deleteCalls += 1;
                            },
                        onExitToMyGubs: onExitToMyGubs,
                      ),
                    ),
                  ),
                  child: const Text('Open Manage'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Profile'));
      await tester.pump();
      await tester.tap(find.text('Open Manage'));
      await tester.pumpAndSettle();
      await _completeDeletion(tester);

      expect(deleteCalls, 1);
      expect(find.byType(MainNavigationShell), findsOneWidget);
      expect(find.text('Shell My Gubs'), findsOneWidget);
      expect(find.byType(GubifyBottomNavigationBar), findsOneWidget);
      expect(find.text('Delete this Gub?'), findsNothing);
    },
  );
}

Future<void> _completeDeletion(WidgetTester tester) async {
  await tester.tap(find.text('Delete Gub'));
  await tester.pumpAndSettle();
  expect(find.text('Delete this Gub?'), findsOneWidget);

  await tester.enterText(find.byType(TextField), 'Private Gub');
  await tester.pump();
  final deleteButton = find.widgetWithText(
    FilledButton,
    'Delete Gub permanently',
  );
  await tester.ensureVisible(deleteButton);
  await tester.pump();
  expect(tester.widget<FilledButton>(deleteButton).onPressed, isNotNull);
  expect(deleteButton.hitTestable(), findsOneWidget);
  await tester.tap(deleteButton);
  await tester.pumpAndSettle();
}
