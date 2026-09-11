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

  testWidgets('visible Back sits below progress and above the artwork', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    final progress = tester.getRect(
      find.byKey(const Key('community-guidelines-progress-0')),
    );
    final back = tester.getRect(
      find.byKey(const Key('community-guidelines-back')),
    );
    final artwork = tester.getRect(
      find.byKey(const Key('community-guidelines-page-0')),
    );

    expect(back.top, greaterThanOrEqualTo(progress.bottom));
    expect(back.bottom, lessThanOrEqualTo(artwork.top));
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('visible Back returns to the previous onboarding page', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final pageView = tester.widget<PageView>(
      find.byKey(const Key('community-guidelines-pages')),
    );
    pageView.controller!.jumpToPage(2);
    await tester.pump();

    await tester.tap(find.byKey(const Key('community-guidelines-back')));
    await tester.pump();
    await tester.pump(CommunityGuidelinesScreen.pageTransitionDuration);

    expect(_currentPage(tester), closeTo(1, 0.01));
    expect(_progress(tester, 1), lessThan(0.1));
  });

  testWidgets('visible Back exits naturally from the first page', (
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_currentPage(tester), closeTo(0, 0.01));

    await tester.tap(find.byKey(const Key('community-guidelines-back')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
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

  testWidgets('final acceptance controls are laid out below the artwork', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _showFinalPage(tester);

    final artwork = tester.getRect(
      find.byKey(const Key('community-guidelines-page-4')),
    );
    final checkbox = tester.getRect(
      find.byKey(const Key('community-guidelines-checkbox')),
    );

    expect(artwork.bottom, lessThanOrEqualTo(checkbox.top));
  });

  testWidgets('pages four and five keep the same artwork viewport', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final pageView = tester.widget<PageView>(
      find.byKey(const Key('community-guidelines-pages')),
    );
    pageView.controller!.jumpToPage(3);
    await tester.pump();
    final pageFour = tester.getRect(
      find.byKey(const Key('community-guidelines-page-3')),
    );

    pageView.controller!.jumpToPage(4);
    await tester.pump();
    final pageFive = tester.getRect(
      find.byKey(const Key('community-guidelines-page-4')),
    );

    expect(pageFive, pageFour);
    expect(
      tester
          .widget<Image>(find.byKey(const Key('community-guidelines-page-4')))
          .fit,
      BoxFit.contain,
    );
  });

  testWidgets(
    'Guidelines link opens official URL without toggling acceptance',
    (tester) async {
      Uri? launched;
      await tester.pumpWidget(
        _app(
          launchGuidelines: (uri) async {
            launched = uri;
            return true;
          },
        ),
      );
      await _showFinalPage(tester);

      await tester.tap(find.text('Community Guidelines'));
      await tester.pump();

      expect(launched, Uri.parse('https://gubify.com/guidelines'));
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    },
  );

  testWidgets('failed Guidelines launch stays unaccepted and shows an error', (
    tester,
  ) async {
    var accepts = 0;
    await tester.pumpWidget(
      _app(
        onAccept: () async => accepts++,
        launchGuidelines: (_) async => false,
      ),
    );
    await _showFinalPage(tester);

    await tester.tap(find.text('Community Guidelines'));
    await tester.pump();

    expect(find.text('Unable to open Community Guidelines.'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(accepts, 0);
  });

  testWidgets('saving blocks Back and swipe navigation', (tester) async {
    final pending = Completer<void>();
    await tester.pumpWidget(_app(onAccept: () => pending.future));
    await _showFinalPage(tester);
    await tester.tap(find.byKey(const Key('community-guidelines-checkbox')));
    await tester.pump();
    await tester.tap(find.text('I understand and continue'));
    await tester.pump();

    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('community-guidelines-back')),
          )
          .onPressed,
      isNull,
    );

    await tester.binding.handlePopRoute();
    await tester.pump(CommunityGuidelinesScreen.pageTransitionDuration);
    await tester.drag(
      find.byKey(const Key('community-guidelines-pages')),
      const Offset(500, 0),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(_currentPage(tester), closeTo(4, 0.01));
    pending.complete();
    await tester.pump();
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
    final exception = tester.takeException();
    expect(exception, isNull);
  });
}

Widget _app({
  Future<void> Function()? onAccept,
  VoidCallback? onAccepted,
  Future<bool> Function(Uri)? launchGuidelines,
}) {
  return MaterialApp(
    home: CommunityGuidelinesScreen(
      onAccept: onAccept ?? () async {},
      onAccepted: onAccepted ?? () {},
      launchGuidelines: launchGuidelines,
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
