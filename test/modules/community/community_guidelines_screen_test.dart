import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/guidelines/community_guidelines_screen.dart';

void main() {
  testWidgets('uses five ordered images and five story progress segments', (
    tester,
  ) async {
    expect(CommunityGuidelinesScreen.imageAssets, const [
      'assets/images/onboarding/community/community_01.png',
      'assets/images/onboarding/community/community_02.png',
      'assets/images/onboarding/community/community_03.png',
      'assets/images/onboarding/community/community_04.png',
      'assets/images/onboarding/community/community_05.png',
    ]);

    await tester.pumpWidget(_app());

    expect(find.byType(LinearProgressIndicator), findsNWidgets(5));
    expect(
      find.byKey(const Key('community-guidelines-page-0')),
      findsOneWidget,
    );
    expect(find.text('I have read the Community Guidelines'), findsNothing);
  });

  testWidgets('auto advances pages 1 to 4 after ten seconds', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.pump(const Duration(seconds: 9, milliseconds: 999));
    expect(_currentPage(tester), closeTo(0, 0.01));
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();
    await tester.pump(CommunityGuidelinesScreen.pageTransitionDuration);
    expect(_currentPage(tester), closeTo(1, 0.01));

    for (var page = 2; page <= 4; page++) {
      await tester.pump();
      await tester.pump(
        CommunityGuidelinesScreen.autoAdvanceDuration +
            const Duration(milliseconds: 1),
      );
      await tester.pump();
      await tester.pump(CommunityGuidelinesScreen.pageTransitionDuration);
      expect(_currentPage(tester), closeTo(page, 0.01));
    }

    await tester.pump(const Duration(seconds: 30));
    expect(_currentPage(tester), closeTo(4, 0.01));
  });

  testWidgets('manual forward and back navigation resets story progress', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    await tester.drag(
      find.byKey(const Key('community-guidelines-pages')),
      const Offset(-500, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(_currentPage(tester), closeTo(1, 0.01));
    expect(_progress(tester, 1), lessThan(0.1));

    await tester.drag(
      find.byKey(const Key('community-guidelines-pages')),
      const Offset(500, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_currentPage(tester), closeTo(0, 0.01));
    expect(_progress(tester, 0), lessThan(0.1));
  });

  testWidgets('a manual page change cancels stale autoplay progress', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));

    final pageView = tester.widget<PageView>(
      find.byKey(const Key('community-guidelines-pages')),
    );
    pageView.controller!.jumpToPage(1);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(_currentPage(tester), closeTo(1, 0.01));
  });

  testWidgets('autoplay pauses with app lifecycle and resumes remaining time', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 20));
    expect(_currentPage(tester), closeTo(0, 0.01));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 6, milliseconds: 1));
    await tester.pump();
    await tester.pump(CommunityGuidelinesScreen.pageTransitionDuration);
    expect(_currentPage(tester), closeTo(1, 0.01));
  });

  testWidgets('final page requires checkbox and persists exactly once', (
    tester,
  ) async {
    final pending = Completer<void>();
    var writes = 0;
    var accepted = 0;
    await tester.pumpWidget(
      _app(
        onAccept: () {
          writes++;
          return pending.future;
        },
        onAccepted: () => accepted++,
      ),
    );
    await _showFinalPage(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'I understand and continue'),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.byKey(const Key('community-guidelines-checkbox')));
    await tester.pump();
    await tester.tap(find.text('I understand and continue'));
    await tester.tap(find.text('I understand and continue'));
    await tester.pump();
    expect(writes, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete();
    await tester.pump();
    expect(accepted, 1);
  });

  testWidgets('saving failure keeps the checkbox selected for retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      _app(
        onAccept: () async {
          attempts++;
          if (attempts == 1) throw StateError('offline');
        },
      ),
    );
    await _showFinalPage(tester);
    await tester.tap(find.byKey(const Key('community-guidelines-checkbox')));
    await tester.pump();
    await tester.tap(find.text('I understand and continue'));
    await tester.pump();

    expect(
      find.text('Unable to save your acceptance. Please try again.'),
      findsOneWidget,
    );
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'I understand and continue'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('system Back moves through pages then exits from the first', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CommunityGuidelinesScreen(
                  onAccept: () async {},
                  onAccepted: () {},
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await _showFinalPage(tester);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(CommunityGuidelinesScreen.pageTransitionDuration);
    expect(_currentPage(tester), closeTo(3, 0.01));

    final pageView = tester.widget<PageView>(
      find.byKey(const Key('community-guidelines-pages')),
    );
    pageView.controller!.jumpToPage(0);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('fits a narrow phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await _showFinalPage(tester);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({Future<void> Function()? onAccept, VoidCallback? onAccepted}) {
  return MaterialApp(
    home: CommunityGuidelinesScreen(
      onAccept: onAccept ?? () async {},
      onAccepted: onAccepted ?? () {},
    ),
  );
}

double _currentPage(WidgetTester tester) {
  final pageView = tester.widget<PageView>(
    find.byKey(const Key('community-guidelines-pages')),
  );
  return pageView.controller!.page!;
}

double _progress(WidgetTester tester, int index) {
  return tester
          .widget<LinearProgressIndicator>(
            find.byKey(Key('community-guidelines-progress-$index')),
          )
          .value ??
      0;
}

Future<void> _showFinalPage(WidgetTester tester) async {
  final pageView = tester.widget<PageView>(
    find.byKey(const Key('community-guidelines-pages')),
  );
  pageView.controller!.jumpToPage(4);
  await tester.pump();
}
