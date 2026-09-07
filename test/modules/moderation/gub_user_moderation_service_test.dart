import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/moderation/models/community_report_model.dart';
import 'package:gubify/modules/moderation/gub_reporting/models/gub_user_moderation_report.dart';
import 'package:gubify/modules/moderation/gub_reporting/services/gub_user_moderation_service.dart';
import 'package:gubify/modules/profile/models/user_profile_model.dart';

void main() {
  group('GubUserModerationService', () {
    test('submits an authoritative private Gub user report', () async {
      GubUserModerationReport? submitted;
      final service = _service(
        createReport: (report) async {
          submitted = report;
          return true;
        },
      );

      await service.reportUser(
        gubId: 'gub-1',
        user: const UserProfileModel(
          userId: 'target-1',
          displayName: 'Stale UI name',
          isCurrentUser: false,
        ),
        reason: 'harassment_or_bullying',
        details: '  Repeated unwanted contact.  ',
      );

      expect(submitted, isNotNull);
      expect(submitted!.reportId, 'user__gub__gub-1__target-1__reporter-1');
      expect(submitted!.targetType, 'user');
      expect(submitted!.targetId, 'target-1');
      expect(submitted!.targetUserId, 'target-1');
      expect(submitted!.gubNameSnapshot, 'Authoritative Gub');
      expect(submitted!.targetNameSnapshot, 'Authoritative target');
      expect(submitted!.details, 'Repeated unwanted contact.');
      expect(submitted!.moderationTargetKey, 'user__target-1');
    });

    test('rejects an unsupported reason before writing', () async {
      var writes = 0;
      final service = _service(
        createReport: (_) async {
          writes += 1;
          return true;
        },
      );

      await expectLater(
        service.reportUser(
          gubId: 'gub-1',
          user: _target,
          reason: 'unsupported',
          details: '',
        ),
        throwsArgumentError,
      );

      expect(writes, 0);
    });

    test('rejects details longer than 500 characters before writing', () async {
      var writes = 0;
      final service = _service(
        createReport: (_) async {
          writes += 1;
          return true;
        },
      );

      await expectLater(
        service.reportUser(
          gubId: 'gub-1',
          user: _target,
          reason: 'spam',
          details: 'x' * 501,
        ),
        throwsArgumentError,
      );

      expect(writes, 0);
    });

    test('rejects unauthenticated and self reports', () async {
      final unauthenticated = GubUserModerationService.forTesting(
        currentUserId: () => null,
        loadGub: (_) async => _gub,
        loadMember: (_, _) async => _member,
        createReport: (_) async => true,
      );
      final self = _service(currentUserId: () => 'target-1');

      await expectLater(
        unauthenticated.reportUser(
          gubId: 'gub-1',
          user: _target,
          reason: 'spam',
          details: '',
        ),
        throwsStateError,
      );
      await expectLater(
        self.reportUser(
          gubId: 'gub-1',
          user: _target,
          reason: 'spam',
          details: '',
        ),
        throwsArgumentError,
      );
    });

    test(
      'maps a duplicate repository result to the existing duplicate error',
      () {
        final service = _service(createReport: (_) async => false);

        expect(
          service.reportUser(
            gubId: 'gub-1',
            user: _target,
            reason: 'spam',
            details: '',
          ),
          throwsA(isA<CommunityReportAlreadyExistsException>()),
        );
      },
    );

    test('rejects unavailable Gubs and target memberships', () async {
      final missingGub = _service(loadGub: (_) async => null);
      final missingTarget = _service(loadMember: (_, _) async => null);

      await expectLater(
        missingGub.reportUser(
          gubId: 'gub-1',
          user: _target,
          reason: 'spam',
          details: '',
        ),
        throwsStateError,
      );
      await expectLater(
        missingTarget.reportUser(
          gubId: 'gub-1',
          user: _target,
          reason: 'spam',
          details: '',
        ),
        throwsStateError,
      );
    });
  });
}

const _target = UserProfileModel(
  userId: 'target-1',
  displayName: 'Stale UI name',
  isCurrentUser: false,
);

const _gub = <String, dynamic>{
  'name': 'Authoritative Gub',
  'deletionStatus': 'active',
};

const _member = <String, dynamic>{
  'uid': 'target-1',
  'displayName': 'Authoritative target',
};

GubUserModerationService _service({
  String? Function()? currentUserId,
  Future<Map<String, dynamic>?> Function(String gubId)? loadGub,
  Future<Map<String, dynamic>?> Function(String gubId, String uid)? loadMember,
  Future<bool> Function(GubUserModerationReport report)? createReport,
}) => GubUserModerationService.forTesting(
  currentUserId: currentUserId ?? () => 'reporter-1',
  loadGub: loadGub ?? (_) async => _gub,
      loadMember: loadMember ?? (_, _) async => _member,
  createReport: createReport ?? (_) async => true,
);
