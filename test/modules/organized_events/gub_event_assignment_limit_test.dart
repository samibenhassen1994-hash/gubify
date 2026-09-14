import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/organized_events/screens/create_gub_event_screen.dart';
import 'package:gubify/modules/organized_events/services/gub_event_service.dart';

void main() {
  test(
    '20 Organized Event assignments are accepted by application validation',
    () {
      expect(
        () => GubEventService.validateAssignmentCount(20),
        returnsNormally,
      );
    },
  );

  test('21 Organized Event assignments are rejected before Firestore', () {
    expect(
      () => GubEventService.validateAssignmentCount(21),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          GubEventService.assignmentLimitMessage,
        ),
      ),
    );
  });

  testWidgets('Create Event prevents selecting a twenty-first member', (
    tester,
  ) async {
    final members = List.generate(
      21,
      (index) => {'userId': 'member-$index', 'userName': 'Member $index'},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CreateGubEventScreen(
          gubId: 'gub-1',
          membersLoader: (_) async => members,
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder memberTile(int index) => find.byWidgetPredicate(
      (widget) =>
          widget is CheckboxListTile &&
          widget.title is Text &&
          (widget.title! as Text).data == 'Member $index',
    );
    final formScrollView = find.byType(Scrollable).first;

    for (var index = 0; index < 20; index++) {
      final tile = memberTile(index).first;
      await tester.scrollUntilVisible(tile, 120, scrollable: formScrollView);
      await tester.tap(tile);
      await tester.pump();
    }

    final twentyFirst = memberTile(20).first;
    await tester.scrollUntilVisible(
      twentyFirst,
      120,
      scrollable: formScrollView,
    );
    await tester.tap(twentyFirst);
    await tester.pump();

    expect(find.text(GubEventService.assignmentLimitMessage), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(twentyFirst).value, isFalse);
  });
}
