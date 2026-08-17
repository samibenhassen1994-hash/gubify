import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/screens/welcome_screen.dart';

void main() {
  testWidgets('fits a short screen without scrolling or overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 426));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomeScreen(
          headerOverride: SizedBox(height: 52),
          greetingOverride: SizedBox(
            height: 31,
            child: Center(child: Text('Hi, Test')),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(Scrollable), findsNothing);
    expect(find.text('Create Gub'), findsOneWidget);
    expect(find.text('My Gubs'), findsOneWidget);
    expect(find.text('Join a Gub'), findsOneWidget);
    expect(find.text('Learn More'), findsOneWidget);
    expect(find.text('Support Us'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final action in [
      find.text('Create Gub'),
      find.text('My Gubs'),
      find.text('Join a Gub'),
      find.text('Learn More'),
      find.text('Support Us'),
    ]) {
      expect(tester.getBottomRight(action).dy, lessThanOrEqualTo(426));
    }
  });

  testWidgets('keeps the normal layout non-scrollable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomeScreen(
          headerOverride: SizedBox(height: 96),
          greetingOverride: SizedBox(
            height: 36,
            child: Center(child: Text('Hi, Test')),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(Scrollable), findsNothing);
    expect(find.text('Create Gub'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
