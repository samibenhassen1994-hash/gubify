import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/widgets/community_pending_requests_button.dart';

void main() {
  testWidgets('hides zero, shows updates, caps at 99+, and handles errors', (
    tester,
  ) async {
    final controller = StreamController<int>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityPendingRequestsButton(
            countStream: controller.stream,
            onPressed: () {},
          ),
        ),
      ),
    );

    controller.add(0);
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNothing);

    controller.add(3);
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);

    controller.add(120);
    await tester.pumpAndSettle();
    expect(find.text('99+'), findsOneWidget);

    controller.addError(StateError('denied'));
    await tester.pumpAndSettle();
    expect(find.text('99+'), findsNothing);
  });

  testWidgets('invokes its owner action once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityPendingRequestsButton(
            countStream: Stream.value(1),
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.how_to_reg_rounded));
    expect(taps, 1);
  });

  testWidgets('does not render or subscribe for a non-owner', (tester) async {
    var subscriptionCount = 0;
    final stream = Stream<int>.multi((_) => subscriptionCount++);

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPendingRequestsButton(
          isVisible: false,
          countStream: stream,
          onPressed: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.how_to_reg_rounded), findsNothing);
    expect(subscriptionCount, 0);
  });
}
