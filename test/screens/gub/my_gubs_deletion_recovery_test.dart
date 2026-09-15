import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/screens/gub/gub_screen.dart';
import 'package:gubify/screens/gub/my_gubs_screen.dart';

void main() {
  const activeGub = <String, dynamic>{
    'gubId': 'gub-1',
    'name': 'Active copy',
    'role': 'owner',
    'isFounder': true,
  };
  const deletingGub = <String, dynamic>{
    'gubId': 'gub-1',
    'name': 'rex',
    'ownerId': 'owner',
    'deletionStatus': 'deleting',
    'deletionRequestedBy': 'owner',
  };

  test('recovery Gub takes priority over a remaining user copy', () {
    expect(
      activePrivateGubsWithoutRecovery(
        activeGubs: const [activeGub],
        recoveryGubs: const [deletingGub],
      ),
      isEmpty,
    );
  });

  testWidgets('normal user copy keeps the existing private Gub card', (
    tester,
  ) async {
    var normalOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivateGubsWindow(
            snapshot: const AsyncSnapshot.withData(ConnectionState.active, [
              activeGub,
            ]),
            recoverySnapshot: const AsyncSnapshot.withData(
              ConnectionState.active,
              <Map<String, dynamic>>[],
            ),
            onRetry: _noop,
            onOpen: (_) => normalOpens++,
            onResumeDeletion: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Active copy'), findsOneWidget);
    expect(find.textContaining('Deletion in progress'), findsNothing);
    await tester.tap(find.text('Active copy'));
    expect(normalOpens, 1);
  });

  testWidgets('missing user copy still shows owned deletion recovery', (
    tester,
  ) async {
    var resumedGubId = '';
    var normalOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivateGubsWindow(
            snapshot: const AsyncSnapshot.withData(
              ConnectionState.active,
              <Map<String, dynamic>>[],
            ),
            recoverySnapshot: const AsyncSnapshot.withData(
              ConnectionState.active,
              [deletingGub],
            ),
            onRetry: _noop,
            onOpen: (_) => normalOpens++,
            onResumeDeletion: (gub) => resumedGubId = gub['gubId'] as String,
          ),
        ),
      ),
    );

    expect(find.text('Deletion in progress — rex'), findsOneWidget);
    expect(find.text('Resume deletion'), findsOneWidget);
    await tester.tap(find.text('Resume deletion'));

    expect(resumedGubId, 'gub-1');
    expect(normalOpens, 0);
  });

  testWidgets('recovery disappears after the root Gub is deleted', (
    tester,
  ) async {
    Widget build(List<Map<String, dynamic>> recoveryGubs) => MaterialApp(
      home: Scaffold(
        body: PrivateGubsWindow(
          snapshot: const AsyncSnapshot.withData(
            ConnectionState.active,
            <Map<String, dynamic>>[],
          ),
          recoverySnapshot: AsyncSnapshot.withData(
            ConnectionState.active,
            recoveryGubs,
          ),
          onRetry: _noop,
          onOpen: (_) {},
          onResumeDeletion: (_) {},
        ),
      ),
    );

    await tester.pumpWidget(build(const [deletingGub]));
    expect(find.text('Resume deletion'), findsOneWidget);

    await tester.pumpWidget(build(const []));
    expect(find.text('Resume deletion'), findsNothing);
  });

  test('recovery destination is the existing GubScreen', () {
    final destination = buildGubDeletionRecoveryDestination('gub-1');

    expect(destination, isA<GubScreen>());
    expect((destination as GubScreen).gubId, 'gub-1');
  });
}

void _noop() {}
