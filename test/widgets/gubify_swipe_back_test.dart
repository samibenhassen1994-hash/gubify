import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/widgets/gubify_swipe_back.dart';

void main() {
  testWidgets('sufficient left-edge drag triggers back exactly once', (
    tester,
  ) async {
    var backCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GubifySwipeBack(
          onBack: () => backCalls += 1,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(10, 220));
    await gesture.moveBy(const Offset(90, 4));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.up();
    await tester.pump();

    expect(backCalls, 1);
  });

  testWidgets('drag beginning away from the left edge does nothing', (
    tester,
  ) async {
    var backCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GubifySwipeBack(
          onBack: () => backCalls += 1,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(80, 220));
    await gesture.moveBy(const Offset(120, 0));
    await gesture.up();

    expect(backCalls, 0);
  });

  testWidgets('short left-edge drag does nothing', (tester) async {
    var backCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GubifySwipeBack(
          onBack: () => backCalls += 1,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(10, 220));
    await gesture.moveBy(const Offset(45, 0));
    await gesture.up();

    expect(backCalls, 0);
  });

  testWidgets('primarily vertical left-edge drag does nothing', (tester) async {
    var backCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GubifySwipeBack(
          onBack: () => backCalls += 1,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(10, 220));
    await gesture.moveBy(const Offset(80, 120));
    await gesture.up();

    expect(backCalls, 0);
  });

  testWidgets(
    'initial movement away from Back direction cannot later trigger',
    (tester) async {
      var backs = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: GubifySwipeBack(
            onBack: () => backs += 1,
            child: const Scaffold(body: Text('Content')),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(10, 220));
      await gesture.moveBy(const Offset(-8, 0));
      await gesture.moveBy(const Offset(100, 0));
      await gesture.up();

      expect(backs, 0);
    },
  );

  testWidgets('vertical drag in the edge strip still scrolls the child', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: GubifySwipeBack(
          child: Scaffold(
            body: ListView(
              controller: controller,
              children: const [SizedBox(height: 1200)],
            ),
          ),
        ),
      ),
    );

    await tester.dragFrom(const Offset(10, 500), const Offset(0, -240));
    await tester.pump();

    expect(controller.offset, greaterThan(0));
  });

  testWidgets('tap in the edge strip still reaches the child control', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GubifySwipeBack(
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 24,
                height: 80,
                child: GestureDetector(onTap: () => taps += 1),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(10, 40));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('PageView swipe away from the edge remains functional', (
    tester,
  ) async {
    final controller = PageController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: GubifySwipeBack(
          child: PageView(
            controller: controller,
            children: const [Text('First'), Text('Second')],
          ),
        ),
      ),
    );

    await tester.flingFrom(const Offset(300, 300), const Offset(-500, 0), 1200);
    await tester.pumpAndSettle();

    expect(controller.page, closeTo(1, 0.01));
  });
}
