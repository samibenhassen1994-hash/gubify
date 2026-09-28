import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_access_request_model.dart';
import 'package:gubify/modules/community/repositories/community_repository.dart';

class _DocumentSnapshotFake implements DocumentSnapshot<Map<String, dynamic>> {
  _DocumentSnapshotFake(this.id, this._data);

  @override
  final String id;

  final Map<String, dynamic> _data;

  @override
  bool get exists => true;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Community join request lifecycle', () {
    test('fromFirestore reads requestedAt', () {
      final requestedAt = Timestamp.fromMillisecondsSinceEpoch(1234);

      final model = CommunityAccessRequestModel.fromFirestore(
        _DocumentSnapshotFake('requester', {
          'userId': 'requester',
          'displayName': 'Requester',
          'status': CommunityAccessRequestModel.pendingStatus,
          'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
          'requestedAt': requestedAt,
        }),
      );

      expect(model.requestedAt, same(requestedAt));
    });

    test('initial request payload writes createdAt and requestedAt', () {
      final payload = CommunityRepository.joinRequestCreatePayload(
        userId: 'requester',
        displayName: 'Requester',
      );

      expect(payload['status'], CommunityAccessRequestModel.pendingStatus);
      expect(payload['createdAt'], isA<FieldValue>());
      expect(payload['requestedAt'], isA<FieldValue>());
    });

    test('reset payload rotates only requestedAt and clears resolution', () {
      final payload = CommunityRepository.joinRequestResetPayload();

      expect(payload['status'], CommunityAccessRequestModel.pendingStatus);
      expect(payload['requestedAt'], isA<FieldValue>());
      expect(payload['resolvedAt'], isA<FieldValue>());
      expect(payload['resolvedBy'], isA<FieldValue>());
      expect(payload, isNot(contains('createdAt')));
    });

    test('approval and rejection payloads preserve requestedAt', () {
      final approval = CommunityRepository.joinRequestResolutionPayload(
        status: CommunityAccessRequestModel.approvedStatus,
        ownerId: 'owner',
      );
      final rejection = CommunityRepository.joinRequestResolutionPayload(
        status: CommunityAccessRequestModel.rejectedStatus,
        ownerId: 'owner',
      );

      for (final payload in [approval, rejection]) {
        expect(payload['resolvedAt'], isA<FieldValue>());
        expect(payload['resolvedBy'], 'owner');
        expect(payload, isNot(contains('createdAt')));
        expect(payload, isNot(contains('requestedAt')));
      }
    });
  });
}
