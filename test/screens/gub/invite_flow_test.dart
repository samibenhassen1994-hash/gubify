import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/core/invites/invite_code.dart';
import 'package:gubify/core/invites/invite_share_content.dart';
import 'package:gubify/screens/gub/invite_members_screen.dart';
import 'package:gubify/screens/gub/join_gub_screen.dart';
import 'package:gubify/screens/gub/widgets/invite_code_panel.dart';
import 'package:gubify/screens/gub/widgets/invite_members_button.dart';

void main() {
  group('invite share content', () {
    test('builds the formatted code, exact URL, and safe payload', () {
      final content = InviteShareContent.build(
        gubName: 'Sam’s Gub 🚀',
        canonicalCode: 'K7M4P9Q2',
      );

      expect(content.visibleCode, 'K7M4-P9Q2');
      expect(content.url.toString(), 'https://gubify.com/join/K7M4-P9Q2');
      expect(
        content.payload,
        'Join my Gub “Sam’s Gub 🚀” on Gubify.\n\n'
        'Invite code: K7M4-P9Q2\n'
        'https://gubify.com/join/K7M4-P9Q2',
      );
      expect(content.payload, isNot(contains('gubId')));
      expect(content.payload, isNot(contains('ownerId')));
      expect(content.payload, isNot(contains('uid')));
      expect(content.payload, isNot(contains('K7M4P9Q2')));
    });

    test('preserves apostrophes, accents, emoji, spaces, and line breaks', () {
      const name = "  L’été d'Ana 🌻\nFriends  ";
      final content = InviteShareContent.build(
        gubName: name,
        canonicalCode: 'R8T5W3X6',
      );

      expect(content.payload, contains(name));
      expect(content.url.toString(), 'https://gubify.com/join/R8T5-W3X6');
    });

    test('rejects an invalid code or an empty Gub name', () {
      expect(
        () =>
            InviteShareContent.build(gubName: 'Test', canonicalCode: 'INVALID'),
        throwsA(isA<InvalidInviteCodeException>()),
      );
      expect(
        () =>
            InviteShareContent.build(gubName: '   ', canonicalCode: 'K7M4P9Q2'),
        throwsA(isA<InvalidInviteCodeException>()),
      );
    });
  });

  test('Community source remains isolated from private invite UI and data', () {
    final source = Directory('lib/modules/community')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    for (final privateInviteReference in const [
      'InviteCodePanel',
      'InviteMembersScreen',
      'inviteTokenId',
      'inviteTokens',
      'Copy code',
      'Share invite link',
      'gubify.com/join',
    ]) {
      expect(source, isNot(contains(privateInviteReference)));
    }
  });

  testWidgets('Join Gub serializes double taps', (tester) async {
    final pending = Completer<String>();
    var calls = 0;
    String? submittedCode;
    await tester.pumpWidget(
      MaterialApp(
        home: JoinGubScreen(
          showUserHeader: false,
          joinAction: ({required inviteCode}) {
            calls++;
            submittedCode = inviteCode;
            return pending.future;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'k7m4-p9q2');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Join Gub'));
    await tester.tap(find.widgetWithText(FilledButton, 'Join Gub'));
    await tester.pump();

    expect(calls, 1);
    expect(submittedCode, 'K7M4P9Q2');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'K7M4-P9Q2',
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete('g1');
    await tester.pump();
  });

  testWidgets('Join Gub shows the generic invalid-token message', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JoinGubScreen(
          showUserHeader: false,
          joinAction: ({required inviteCode}) async {
            throw const InvalidInviteCodeException();
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'K7M4-P9Q2');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Join Gub'));
    await tester.pump();

    expect(find.text('Invalid or expired invite code.'), findsOneWidget);
  });

  testWidgets('invite panel formats and copies the visible code', (
    tester,
  ) async {
    MethodCall? clipboardCall;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') clipboardCall = call;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InviteCodePanel(
              gubName: 'Test Gub',
              canonicalCode: 'K7M4P9Q2',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Invite code'), findsOneWidget);
    expect(find.text('K7M4-P9Q2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Copy code'));
    await tester.pump();

    expect(clipboardCall?.arguments, {'text': 'K7M4-P9Q2'});
    expect(find.text('Invite code copied'), findsOneWidget);
    expect(find.text('Share invite link'), findsOneWidget);
    expect(
      find.text('Anyone with this invite can join your private Gub.'),
      findsOneWidget,
    );
  });

  testWidgets('Copy code serializes double taps and one confirmation', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) {
        if (call.method == 'Clipboard.setData') {
          calls++;
          return pending.future;
        }
        return Future<void>.value();
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InviteCodePanel(gubName: 'Test Gub', canonicalCode: 'K7M4P9Q2'),
        ),
      ),
    );

    await tester.tap(find.text('Copy code'));
    await tester.tap(find.text('Copy code'));
    await tester.pump();
    expect(calls, 1);
    pending.complete();
    await tester.pump();
    expect(find.text('Invite code copied'), findsOneWidget);
  });

  testWidgets('Share uses the exact payload and a real origin', (tester) async {
    String? payload;
    Rect? origin;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InviteCodePanel(
            gubName: "L'été 🚀",
            canonicalCode: 'K7M4P9Q2',
            shareAction: ({required text, required sharePositionOrigin}) async {
              payload = text;
              origin = sharePositionOrigin;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Share invite link'));
    await tester.pump();

    expect(payload, contains("L'été 🚀"));
    expect(payload, contains('Invite code: K7M4-P9Q2'));
    expect(payload, contains('https://gubify.com/join/K7M4-P9Q2'));
    expect(origin, isNotNull);
    expect(origin!.isEmpty, isFalse);
  });

  testWidgets('Share serializes double taps and re-enables after returning', (
    tester,
  ) async {
    final firstShare = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InviteCodePanel(
            gubName: 'Test Gub',
            canonicalCode: 'K7M4P9Q2',
            shareAction: ({required text, required sharePositionOrigin}) {
              calls++;
              return firstShare.future;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Share invite link'));
    await tester.tap(find.text('Share invite link'));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Opening…'), findsOneWidget);

    firstShare.complete();
    await tester.pump();
    expect(find.text('Share invite link'), findsOneWidget);
  });

  testWidgets('share failure stays generic and does not lock the action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InviteCodePanel(
            gubName: 'Test Gub',
            canonicalCode: 'K7M4P9Q2',
            shareAction: ({required text, required sharePositionOrigin}) async {
              throw StateError('technical detail');
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Share invite link'));
    await tester.pump();
    expect(find.text('Invite unavailable. Please try again.'), findsOneWidget);
    expect(find.textContaining('technical detail'), findsNothing);
    expect(find.text('Share invite link'), findsOneWidget);
  });

  testWidgets('missing, invalid, and inactive invites disable both actions', (
    tester,
  ) async {
    Future<void> verify(String code, {bool available = true}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InviteCodePanel(
              gubName: 'Test Gub',
              canonicalCode: code,
              inviteAvailable: available,
            ),
          ),
        ),
      );
      expect(find.text('Unavailable'), findsOneWidget);
      expect(
        find.text('Invite unavailable. Please try again.'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
    }

    await verify('');
    await verify('INVALID');
    await verify('K7M4P9Q2', available: false);
  });

  testWidgets('pending share can finish after dispose without an exception', (
    tester,
  ) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InviteCodePanel(
            gubName: 'Test Gub',
            canonicalCode: 'K7M4P9Q2',
            shareAction: ({required text, required sharePositionOrigin}) =>
                pending.future,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Share invite link'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long Unicode name, narrow screen, and large text do not overflow',
    (tester) async {
      tester.view.physicalSize = const Size(280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: InviteCodePanel(
                gubName:
                    'Un nome molto lungo con accenti, apostrofi ed emoji 🌍🚀✨',
                canonicalCode: 'K7M4P9Q2',
              ),
            ),
          ),
        ),
      );

      expect(find.text('K7M4-P9Q2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Invite screen shows a generic load error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InviteMembersScreen(
          gubId: 'g1',
          showUserHeader: false,
          loadGub: (_) async => throw StateError('Firestore detail'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Invite unavailable. Please try again.'), findsOneWidget);
    expect(find.textContaining('Firestore detail'), findsNothing);
  });

  testWidgets('Invite navigation serializes taps while the route is open', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InviteMembersButton(
            gubId: 'g1',
            openAction: (context, gubId) {
              calls++;
              expect(gubId, 'g1');
              return pending.future;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Invite Members'));
    await tester.tap(find.text('Invite Members'));
    await tester.pump();
    expect(calls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
