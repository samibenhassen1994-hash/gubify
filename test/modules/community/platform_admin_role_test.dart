import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/admin/platform_admin_service.dart';
import 'package:gubify/modules/community/admin/platform_admin_gate.dart';

void main() {
  late StreamController<PlatformAdminIdentity?> identities;
  late Map<String, StreamController<bool>> roles;
  late PlatformAdminService service;
  Future<void> tick() => Future<void>.delayed(Duration.zero);
  setUp(() {
    identities = StreamController<PlatformAdminIdentity?>.broadcast(sync: true);
    roles = {
      'one': StreamController<bool>.broadcast(sync: true),
      'two': StreamController<bool>.broadcast(sync: true),
    };
    service = PlatformAdminService(
      identities: identities.stream,
      watchActive: (uid) => roles[uid]!.stream,
    );
  });
  tearDown(() async {
    service.dispose();
    await identities.close();
    for (final role in roles.values) {
      await role.close();
    }
  });
  test(
    'role fails closed on account switch, anonymous account, error and logout',
    () async {
      identities.add(
        const PlatformAdminIdentity(uid: 'one', isAnonymous: false),
      );
      await tick();
      roles['one']!.add(true);
      await tick();
      expect(service.isAdmin, true);
      identities.add(
        const PlatformAdminIdentity(uid: 'two', isAnonymous: false),
      );
      await tick();
      expect(service.isAdmin, false);
      roles['one']!.add(true);
      await tick();
      expect(service.isAdmin, false);
      roles['two']!.add(true);
      await tick();
      expect(service.isAdmin, true);
      roles['two']!.addError(StateError('permission denied'));
      await tick();
      expect(service.isAdmin, false);
      identities.add(
        const PlatformAdminIdentity(uid: 'one', isAnonymous: true),
      );
      await tick();
      roles['one']!.add(true);
      await tick();
      expect(service.isAdmin, false);
      identities.add(null);
      await tick();
      expect(service.isAdmin, false);
    },
  );
  testWidgets(
    'admin entry opens protected route and revocation removes mounted content',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformAdminEntry(
              service: service,
              screenBuilder: (_) => const Text('Moderation resources'),
            ),
          ),
        ),
      );
      expect(find.text('Community moderation'), findsNothing);
      identities.add(
        const PlatformAdminIdentity(uid: 'one', isAnonymous: false),
      );
      await tester.pump();
      roles['one']!.add(true);
      await tester.pump();
      await tester.tap(find.text('Community moderation'));
      await tester.pumpAndSettle();
      expect(find.text('Moderation resources'), findsOneWidget);
      roles['one']!.add(false);
      await tester.pump();
      expect(find.text('Moderation resources'), findsNothing);
      expect(
        find.text('Community moderation access is unavailable.'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pump();
      expect(find.text('Community moderation'), findsNothing);
    },
  );
}
