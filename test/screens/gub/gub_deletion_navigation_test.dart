import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/screens/gub/gub_deletion_navigation.dart';
import 'package:gubify/screens/gub/my_gubs_screen.dart';

void main() {
  test('keeps the owner in recovery while deletion is in progress', () {
    expect(
      resolveGubDeletionRouteAction(
        gubData: const {'ownerId': 'owner', 'deletionStatus': 'deleting'},
        currentUserId: 'owner',
      ),
      GubDeletionRouteAction.stay,
    );
  });

  test('ejects a non-owner as soon as deletion starts', () {
    expect(
      resolveGubDeletionRouteAction(
        gubData: const {'ownerId': 'owner', 'deletionStatus': 'deleting'},
        currentUserId: 'member',
      ),
      GubDeletionRouteAction.exitWithOwnerMessage,
    );
  });

  test('exits safely after the Gub root disappears', () {
    expect(
      resolveGubDeletionRouteAction(gubData: null, currentUserId: 'owner'),
      GubDeletionRouteAction.exitSilently,
    );
  });

  testWidgets('uses MyGubsScreen as the production destination', (
    tester,
  ) async {
    final controller = GubDeletionNavigationController();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expect(controller.buildDestination(context), isA<MyGubsScreen>());
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('opens the destination once and clears the previous stack', (
    tester,
  ) async {
    var destinationBuilds = 0;
    final navigatorKey = GlobalKey<NavigatorState>();
    final controller = GubDeletionNavigationController(
      destinationBuilder: (_) {
        destinationBuilds++;
        return const Scaffold(body: Text('My Gubs destination'));
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () {
                controller.scheduleExit(context);
                controller.scheduleExit(context);
              },
              child: const Text('Complete deletion'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Complete deletion'));
    await tester.pumpAndSettle();

    expect(find.text('My Gubs destination'), findsOneWidget);
    expect(destinationBuilds, 1);
    expect(controller.navigationScheduled, isTrue);
    expect(navigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('shows the member deletion message once', (tester) async {
    final controller = GubDeletionNavigationController(
      destinationBuilder: (_) => const Scaffold(body: Text('My Gubs')),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () {
                controller.scheduleExit(
                  context,
                  message: 'This Gub is being deleted by its owner.',
                );
                controller.scheduleExit(
                  context,
                  message: 'This Gub is being deleted by its owner.',
                );
              },
              child: const Text('Deletion detected'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Deletion detected'));
    await tester.pumpAndSettle();

    expect(find.text('My Gubs'), findsOneWidget);
    expect(
      find.text('This Gub is being deleted by its owner.'),
      findsOneWidget,
    );
  });

  testWidgets('does not navigate with an unmounted context', (tester) async {
    final controller = GubDeletionNavigationController(
      destinationBuilder: (_) => const Text('Unexpected destination'),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Source', key: Key('source'))),
      ),
    );
    final context = tester.element(find.byKey(const Key('source')));

    expect(controller.scheduleExit(context), isTrue);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Replacement'))),
    );
    await tester.pump();

    expect(find.text('Replacement'), findsOneWidget);
    expect(find.text('Unexpected destination'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
