import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/notifications/models/notification_model.dart';
import 'package:gubify/modules/notifications/widgets/notification_card.dart';
import 'package:gubify/repositories/user_repository.dart';

void main() {
  NotificationModel notification({
    String senderId = 'sender',
    String senderName = 'Old name',
    String body = 'Old name created a task.',
  }) => NotificationModel(
    notificationId: 'notification',
    title: 'New task',
    body: body,
    type: 'task_created',
    senderId: senderId,
    senderName: senderName,
    createdAt: Timestamp(1, 0),
    readBy: const [],
    data: const {},
  );

  Widget subject(NotificationModel value, {Stream<UserIdentity>? identity}) =>
      MaterialApp(
        home: Scaffold(
          body: NotificationCard(
            notification: value,
            identity: identity,
            trailing: const SizedBox.shrink(),
          ),
        ),
      );

  testWidgets('active sender renders the current canonical name', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        notification(),
        identity: Stream.value(const UserIdentity.existing('New name')),
      ),
    );
    await tester.pump();

    expect(find.text('New name created a task.'), findsOneWidget);
    expect(find.textContaining('Old name'), findsNothing);
  });

  testWidgets('loading or failed identity keeps the stored snapshot name', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(notification(), identity: const Stream.empty()),
    );
    await tester.pump();

    expect(find.text('Old name created a task.'), findsOneWidget);

    await tester.pumpWidget(
      subject(
        notification(),
        identity: Stream.error(StateError('identity unavailable')),
      ),
    );
    await tester.pump();
    expect(find.text('Old name created a task.'), findsOneWidget);
  });

  testWidgets('deleted and sentinel senders render Deleted user', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        notification(),
        identity: Stream.value(const UserIdentity.missing()),
      ),
    );
    await tester.pump();
    expect(find.text('Deleted user created a task.'), findsOneWidget);

    await tester.pumpWidget(
      subject(notification(senderId: '__deleted_user__')),
    );
    await tester.pump();
    expect(find.text('Deleted user created a task.'), findsOneWidget);
  });

  testWidgets('legacy sender uses snapshot and missing data uses User', (
    tester,
  ) async {
    await tester.pumpWidget(subject(notification(senderId: '')));
    await tester.pump();
    expect(find.text('Old name created a task.'), findsOneWidget);

    await tester.pumpWidget(
      subject(
        notification(senderId: '', senderName: '', body: 'Created a task.'),
      ),
    );
    await tester.pump();
    expect(find.text('User · Created a task.'), findsOneWidget);
  });
}
