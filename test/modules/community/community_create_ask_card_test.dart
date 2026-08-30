import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/widgets/community_create_ask_card.dart';

Widget _card({
  required CommunityDirectAskSubmit onCreate,
  VoidCallback? onCreated,
}) => MaterialApp(
  home: Scaffold(
    body: CommunityCreateAskCard(
      onCreate: onCreate,
      onCreated: onCreated ?? () {},
    ),
  ),
);

void main() {
  testWidgets('title, type chips, and submit action are centered', (
    tester,
  ) async {
    await tester.pumpWidget(
      _card(onCreate: ({required text, required type}) async {}),
    );

    final titleAlign = tester.widget<Align>(
      find
          .ancestor(
            of: find.text('Create ask').first,
            matching: find.byType(Align),
          )
          .first,
    );
    final submitAlign = tester.widget<Align>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('create-ask-submit')),
            matching: find.byType(Align),
          )
          .first,
    );
    final typeWrap = tester.widget<Wrap>(find.byType(Wrap));

    expect(titleAlign.alignment, Alignment.center);
    expect(submitAlign.alignment, Alignment.center);
    expect(typeWrap.alignment, WrapAlignment.center);
  });

  testWidgets('type chips fit a narrow phone card without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _card(onCreate: ({required text, required type}) async {}),
    );

    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Information'), findsOneWidget);
    expect(find.text('Advice'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty text or missing type cannot create a Direct Ask', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _card(onCreate: ({required text, required type}) async => calls++),
    );

    FilledButton submit() =>
        tester.widget(find.byKey(const ValueKey('create-ask-submit')));

    expect(submit().onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('create-ask-text')),
      'A useful question',
    );
    await tester.pump();
    expect(submit().onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('create-ask-type-help')));
    await tester.pump();
    expect(submit().onPressed, isNotNull);
    expect(calls, 0);
  });

  for (final type in CommunityAskType.values) {
    testWidgets('${type.label} Direct Ask submits once and resets on success', (
      tester,
    ) async {
      var calls = 0;
      var created = 0;
      String? capturedText;
      CommunityAskType? capturedType;
      await tester.pumpWidget(
        _card(
          onCreate: ({required text, required type}) async {
            calls++;
            capturedText = text;
            capturedType = type;
          },
          onCreated: () => created++,
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('create-ask-text')),
        '  A useful question  ',
      );
      await tester.tap(find.byKey(ValueKey('create-ask-type-${type.value}')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('create-ask-submit')));
      await tester.pump();

      expect(calls, 1);
      expect(created, 1);
      expect(capturedText, 'A useful question');
      expect(capturedType, type);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('create-ask-text')))
            .controller!
            .text,
        isEmpty,
      );
    });
  }

  testWidgets('pending submission blocks double tap', (tester) async {
    final completer = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      _card(
        onCreate: ({required text, required type}) {
          calls++;
          return completer.future;
        },
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('create-ask-text')),
      'A useful question',
    );
    await tester.tap(find.byKey(const ValueKey('create-ask-type-help')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('create-ask-submit')));
    await tester.pump();

    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('create-ask-submit')))
          .onPressed,
      isNull,
    );
    completer.complete();
    await tester.pump();
  });

  testWidgets('failure preserves text and selected type', (tester) async {
    await tester.pumpWidget(
      _card(
        onCreate: ({required text, required type}) async {
          throw StateError('network');
        },
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('create-ask-text')),
      'Keep this question',
    );
    await tester.tap(find.byKey(const ValueKey('create-ask-type-advice')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('create-ask-submit')));
    await tester.pump();

    expect(find.text('Keep this question'), findsOneWidget);
    expect(
      find.text('Unable to create this ask. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('create-ask-type-advice')),
          )
          .selected,
      isTrue,
    );
  });
}
