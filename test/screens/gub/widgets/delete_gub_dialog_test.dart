import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/screens/gub/widgets/delete_gub_dialog.dart';

void main() {
  testWidgets('shows the Gub name and requires an exact match', (tester) async {
    const gubName = 'Weekend Trip';
    var deleteCalls = 0;
    await _showDeleteDialog(
      tester,
      gubName: gubName,
      onDelete: (_, _) async {
        deleteCalls++;
      },
    );

    expect(find.text(gubName), findsOneWidget);
    expect(_deleteButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'weekend trip');
    await tester.pump();
    expect(_deleteButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), gubName);
    await tester.pump();
    expect(_deleteButton(tester).onPressed, isNotNull);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Delete Gub permanently'),
    );
    await tester.pumpAndSettle();
    expect(deleteCalls, 1);
    expect(find.byType(DeleteGubDialog), findsNothing);
  });

  testWidgets('supports retry after a deletion error', (tester) async {
    var deleteCalls = 0;
    await _showDeleteDialog(
      tester,
      gubName: 'Retry Gub',
      onDelete: (_, _) async {
        deleteCalls++;
        if (deleteCalls == 1) throw Exception('Temporary failure');
      },
    );

    await tester.enterText(find.byType(TextField), 'Retry Gub');
    await tester.pump();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Delete Gub permanently'),
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Delete Gub permanently'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Temporary failure'), findsOneWidget);
    expect(_deleteButton(tester).onPressed, isNotNull);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Delete Gub permanently'),
    );
    await tester.pumpAndSettle();
    expect(deleteCalls, 2);
    expect(find.byType(DeleteGubDialog), findsNothing);
  });

  testWidgets('remains usable on a phone with the keyboard open', (
    tester,
  ) async {
    await _configureView(tester, size: const Size(360, 640), bottomInset: 300);
    await _showDeleteDialog(
      tester,
      gubName: 'Phone Gub',
      onDelete: (_, _) async {},
    );

    expect(_dialogPadding(tester).bottom, 312);
    await tester.enterText(find.byType(TextField), 'Phone Gub');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Delete Gub permanently'),
    );
    await tester.pump();

    expect(
      find.widgetWithText(FilledButton, 'Delete Gub permanently').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(_dialogPadding(tester).bottom, 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets('handles a long name and elevated text scaling', (tester) async {
    const gubName =
        'A very long private Gub name that must remain completely visible in '
        'the confirmation dialog without overflowing the available width';
    await _configureView(tester, size: const Size(360, 700), bottomInset: 260);
    await _showDeleteDialog(
      tester,
      gubName: gubName,
      textScaler: const TextScaler.linear(2),
      onDelete: (_, _) async {},
    );

    expect(find.text(gubName), findsOneWidget);
    await tester.ensureVisible(find.byType(TextField));
    await tester.pump();
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

FilledButton _deleteButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, 'Delete Gub permanently'),
);

EdgeInsets _dialogPadding(WidgetTester tester) =>
    tester.widget<AnimatedPadding>(find.byType(AnimatedPadding)).padding
        as EdgeInsets;

Future<void> _configureView(
  WidgetTester tester, {
  required Size size,
  required double bottomInset,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: bottomInset);
  addTearDown(tester.view.reset);
}

Future<void> _showDeleteDialog(
  WidgetTester tester, {
  required String gubName,
  required DeleteGubCallback onDelete,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) =>
                  DeleteGubDialog(gubName: gubName, onDelete: onDelete),
            ),
            child: const Text('Open dialog'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open dialog'));
  await tester.pumpAndSettle();
}
