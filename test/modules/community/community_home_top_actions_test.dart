import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/widgets/community_home_top_actions.dart';

Widget _screen({required bool isKeyboardOpen}) => MaterialApp(
  home: Scaffold(
    body: CommunityHomeTopActions(
      isKeyboardOpen: isKeyboardOpen,
      pendingRequestsAction: const Icon(Icons.notifications_rounded),
      accountSettingsAction: const Icon(
        Icons.manage_accounts,
        key: ValueKey('account-settings'),
      ),
      reportAction: const Icon(Icons.more_vert, key: ValueKey('report')),
      settingsAction: const Icon(
        Icons.settings_rounded,
        key: ValueKey('settings'),
      ),
    ),
  ),
);

void main() {
  testWidgets('keyboard closed shows Settings and Report actions', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(isKeyboardOpen: false));

    expect(find.byKey(const ValueKey('settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('report')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-settings')), findsOneWidget);
  });

  testWidgets('keyboard open removes Settings and Report actions', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(isKeyboardOpen: true));

    expect(find.byKey(const ValueKey('settings')), findsNothing);
    expect(find.byKey(const ValueKey('report')), findsNothing);
    expect(find.byKey(const ValueKey('account-settings')), findsOneWidget);
    expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
  });

  testWidgets('closing keyboard restores Settings and Report actions', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(isKeyboardOpen: true));
    expect(find.byKey(const ValueKey('settings')), findsNothing);
    expect(find.byKey(const ValueKey('report')), findsNothing);
    expect(find.byKey(const ValueKey('account-settings')), findsOneWidget);

    await tester.pumpWidget(_screen(isKeyboardOpen: false));
    await tester.pump();

    expect(find.byKey(const ValueKey('settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('report')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-settings')), findsOneWidget);
  });

  testWidgets('keyboard visibility applies while Create Ask remains mounted', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(
          body: Column(
            children: [
              CommunityHomeTopActions(
                isKeyboardOpen: true,
                accountSettingsAction: Icon(
                  Icons.manage_accounts,
                  key: ValueKey('account-settings'),
                ),
                reportAction: Icon(Icons.more_vert, key: ValueKey('report')),
                settingsAction: Icon(
                  Icons.settings_rounded,
                  key: ValueKey('settings'),
                ),
              ),
              Expanded(child: TextField(key: ValueKey('create-ask-text'))),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('create-ask-text')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings')), findsNothing);
    expect(find.byKey(const ValueKey('report')), findsNothing);
    expect(find.byKey(const ValueKey('account-settings')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
