import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/chat/screens/chat_screen.dart';

void main() {
  testWidgets('own private message keeps only the four conversion actions', (
    tester,
  ) async {
    await _pumpActions(tester, senderId: 'me');

    await tester.longPress(find.text('Message'));
    await tester.pumpAndSettle();

    _expectConversions();
    expect(find.text('Report message'), findsNothing);
  });

  testWidgets('another private message adds Report message after conversions', (
    tester,
  ) async {
    await _pumpActions(tester, senderId: 'other');

    await tester.longPress(find.text('Message'));
    await tester.pumpAndSettle();

    _expectConversions();
    expect(find.text('Report message'), findsOneWidget);
  });
}

Future<void> _pumpActions(WidgetTester tester, {required String senderId}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onLongPress: () => showChatMessageActions(
                context: context,
                includeReportMessage: senderId != 'me',
              ),
              child: const Text('Message'),
            ),
          ),
        ),
      ),
    );

void _expectConversions() {
  expect(find.text('Task'), findsOneWidget);
  expect(find.text('Proposal'), findsOneWidget);
  expect(find.text('Shared Budget'), findsOneWidget);
  expect(find.text('Event'), findsOneWidget);
}
