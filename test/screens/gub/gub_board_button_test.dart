import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/screens/gub/widgets/gub_board_button.dart';

void main() {
  testWidgets('shows the badge for the first unread Board post and clears it', (
    tester,
  ) async {
    final unreadCounts = StreamController<int>.broadcast(sync: true);
    addTearDown(unreadCounts.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GubBoardButton(
            gubId: 'gub',
            unreadCountStream: unreadCounts.stream,
            onOpenBoard: () {},
          ),
        ),
      ),
    );

    unreadCounts.add(1);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.bySemanticsLabel('Open Board, 1 new posts'), findsOneWidget);

    unreadCounts.add(0);
    await tester.pump();
    expect(find.text('1'), findsNothing);
    expect(find.bySemanticsLabel('Open Board'), findsOneWidget);
  });
}
