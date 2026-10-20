import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/admin/authority_reporting_dialog.dart';
import 'package:gubify/modules/community/admin/platform_admin_service.dart';
import 'package:gubify/modules/community/admin/platform_moderation_model.dart';
import 'package:gubify/modules/community/admin/platform_moderation_repository.dart';
import 'package:gubify/modules/community/admin/platform_moderation_service.dart';

class MemoryAuthorityReferrals extends PlatformModerationRepository {
  final referrals =
      StreamController<List<PlatformAuthorityReferral>>.broadcast();
  final recorded = <({String reportId, String actorId, String channel})>[];

  @override
  Stream<List<PlatformAuthorityReferral>> authorityReferrals(String reportId) {
    return Stream.value(const <PlatformAuthorityReferral>[]);
  }

  @override
  Future<void> recordAuthorityReferral({
    required String reportId,
    required String actorId,
    required String channel,
    required String authorityName,
    required String reference,
    required String note,
  }) async {
    recorded.add((reportId: reportId, actorId: actorId, channel: channel));
  }
}

const childSafetyReport = PlatformReportItem(
  id: 'report-1',
  reason: 'child_safety_or_sexual_exploitation',
  status: 'open',
  sourceName: 'Community',
  sourceKind: 'Community',
  targetType: 'message',
  targetId: 'message-1',
  reporterId: 'reporter-1',
  priority: 'critical',
);

const ordinaryReport = PlatformReportItem(
  id: 'report-2',
  reason: 'spam',
  status: 'open',
  sourceName: 'Community',
  sourceKind: 'Community',
  targetType: 'message',
  targetId: 'message-2',
  reporterId: 'reporter-2',
  priority: 'normal',
);

void main() {
  late StreamController<PlatformAdminIdentity?> identities;
  late StreamController<bool> active;
  late PlatformAdminService role;
  late MemoryAuthorityReferrals repository;
  late PlatformModerationService service;

  setUp(() async {
    identities = StreamController<PlatformAdminIdentity?>.broadcast(sync: true);
    active = StreamController<bool>.broadcast(sync: true);
    role = PlatformAdminService(
      identities: identities.stream,
      watchActive: (_) => active.stream,
    );
    repository = MemoryAuthorityReferrals();
    service = PlatformModerationService(role: role, repository: repository);
    identities.add(
      const PlatformAdminIdentity(uid: 'admin-1', isAnonymous: false),
    );
    active.add(true);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    role.dispose();
    await identities.close();
    await active.close();
    await repository.referrals.close();
  });

  test('authority referral service rejects non-child-safety reports', () async {
    await expectLater(
      service.recordAuthorityReferral(
        report: ordinaryReport,
        channel: 'italian_police',
        authorityName: 'Polizia Postale',
        reference: '',
        note: '',
      ),
      throwsArgumentError,
    );
    expect(repository.recorded, isEmpty);
  });

  testWidgets(
    'records once only after explicit external-submission confirmation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AuthorityReportingDialog(
                    report: childSafetyReport,
                    service: service,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final recordButton = find.widgetWithText(
        FilledButton,
        'Record completed referral',
      );
      expect(tester.widget<FilledButton>(recordButton).onPressed, isNull);

      final confirmation = find.text(
        'I already submitted this report through the official channel.',
      );
      await tester.ensureVisible(confirmation);
      await tester.tap(confirmation);
      await tester.pump();
      expect(tester.widget<FilledButton>(recordButton).onPressed, isNotNull);

      await tester.tap(recordButton);
      await tester.pumpAndSettle();

      expect(find.text('Authority reporting'), findsNothing);
      expect(repository.recorded, [
        (reportId: 'report-1', actorId: 'admin-1', channel: 'italian_police'),
      ]);
    },
  );
}
