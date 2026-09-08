import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/chat/models/chat_message_model.dart';
import 'package:gubify/modules/community/moderation/models/community_report_model.dart';
import 'package:gubify/modules/moderation/gub_reporting/models/gub_message_moderation_report.dart';
import 'package:gubify/modules/moderation/gub_reporting/services/gub_message_moderation_service.dart';

void main() {
  group('GubMessageModerationService', () {
    test('creates a deterministic private Gub message report', () async {
      GubMessageModerationReport? submitted;
      final service = _service(
        createReport: (report) async {
          submitted = report;
          return true;
        },
      );

      await service.reportMessage(
        message: _message,
        reason: 'harassment_or_bullying',
        details: '  Repeated unwanted contact.  ',
      );

      expect(submitted, isNotNull);
      expect(
        submitted!.reportId,
        'message__gub__gub-1__message-1__reporter-1',
      );
      expect(submitted!.targetType, 'user');
      expect(submitted!.targetId, 'author-1');
      expect(submitted!.targetUserId, 'author-1');
      expect(submitted!.messageId, 'message-1');
      expect(submitted!.contentSnapshot, 'Authentic message text');
      expect(submitted!.targetNameSnapshot, 'Message Author');
      expect(submitted!.gubNameSnapshot, 'Authoritative Gub');
      expect(submitted!.details, 'Repeated unwanted contact.');
      expect(submitted!.moderationTargetKey, 'user__author-1');
    });

    test('rejects self reports before writing', () async {
      var writes = 0;
      final service = _service(
        currentUserId: () => 'author-1',
        createReport: (_) async {
          writes++;
          return true;
        },
      );

      await expectLater(
        service.reportMessage(
          message: _message,
          reason: 'spam',
          details: '',
        ),
        throwsArgumentError,
      );
      expect(writes, 0);
    });

    test('rejects invalid reasons and details over 500 characters', () async {
      var writes = 0;
      final service = _service(
        createReport: (_) async {
          writes++;
          return true;
        },
      );

      await expectLater(
        service.reportMessage(
          message: _message,
          reason: 'unsupported',
          details: '',
        ),
        throwsArgumentError,
      );
      await expectLater(
        service.reportMessage(
          message: _message,
          reason: 'spam',
          details: 'x' * 501,
        ),
        throwsArgumentError,
      );
      expect(writes, 0);
    });

    test('maps duplicate reports to the shared friendly exception', () {
      final service = _service(createReport: (_) async => false);

      expect(
        service.reportMessage(
          message: _message,
          reason: 'spam',
          details: '',
        ),
        throwsA(isA<CommunityReportAlreadyExistsException>()),
      );
    });
  });
}

final _message = ChatMessageModel(
  messageId: 'message-1',
  gubId: 'gub-1',
  senderId: 'author-1',
  senderName: 'Message Author',
  text: 'Authentic message text',
  createdAt: Timestamp(1, 0),
);

GubMessageModerationService _service({
  String? Function()? currentUserId,
  Future<Map<String, dynamic>?> Function(String gubId)? loadGub,
  Future<bool> Function(GubMessageModerationReport report)? createReport,
}) => GubMessageModerationService.forTesting(
  currentUserId: currentUserId ?? () => 'reporter-1',
  loadGub:
      loadGub ??
      (_) async => const {
        'name': 'Authoritative Gub',
        'deletionStatus': 'active',
      },
  createReport: createReport ?? (_) async => true,
);
