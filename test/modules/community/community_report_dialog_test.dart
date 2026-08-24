import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/moderation/models/community_report_model.dart';
import 'package:gubify/modules/community/moderation/widgets/community_report_dialog.dart';

void main() {
  Future<void> openDialog(
    WidgetTester tester,
    CommunityReportSubmit onSubmit,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCommunityReportDialog(
                context: context,
                title: 'Report Community',
                onSubmit: onSubmit,
              ),
              child: const Text('Report'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseReason(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spam').last);
    await tester.pumpAndSettle();
  }

  testWidgets('requires a reason and limits details to 500 characters', (
    tester,
  ) async {
    await openDialog(tester, (_, _) async {});

    final details = tester.widget<TextField>(find.byType(TextField));
    expect(details.maxLength, CommunityModerationReport.maxDetailsLength);

    await tester.tap(find.text('Submit report'));
    await tester.pump();
    expect(find.text('Select a reason.'), findsOneWidget);
  });

  testWidgets('disables submit while the report is in progress', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await openDialog(tester, (_, _) {
      calls++;
      return pending.future;
    });
    await chooseReason(tester);

    await tester.tap(find.text('Submit report'));
    await tester.pump();
    expect(calls, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    pending.complete();
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('shows a friendly duplicate-report message', (tester) async {
    await openDialog(
      tester,
      (_, _) async => throw const CommunityReportAlreadyExistsException(),
    );
    await chooseReason(tester);
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    expect(find.text("You've already reported this."), findsOneWidget);
    expect(find.byType(CommunityReportDialog), findsOneWidget);
  });

  testWidgets('successful report closes the dialog and confirms submission', (
    tester,
  ) async {
    await openDialog(tester, (_, _) async {});
    await chooseReason(tester);
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    expect(find.byType(CommunityReportDialog), findsNothing);
    expect(find.text('Report submitted'), findsOneWidget);
  });
}
