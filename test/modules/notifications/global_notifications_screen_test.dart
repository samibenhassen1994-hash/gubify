import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/notifications/screens/global_notifications_screen.dart';
import 'package:gubify/modules/notifications/screens/notifications_screen.dart';

void main() {
  testWidgets('is a listener-free global placeholder', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: GlobalNotificationsScreen()),
    );

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Your notifications will appear here.'), findsOneWidget);
    expect(find.byType(NotificationsScreen), findsNothing);
    expect(find.byType(StreamBuilder<dynamic>), findsNothing);
  });
}
