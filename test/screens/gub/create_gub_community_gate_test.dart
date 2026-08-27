import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/screens/gub/create_gub_screen.dart';

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
}
