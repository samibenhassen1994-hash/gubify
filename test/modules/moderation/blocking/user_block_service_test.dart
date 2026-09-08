import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/moderation/blocking/models/user_block_model.dart';
import 'package:gubify/modules/moderation/blocking/repositories/user_block_repository.dart';
import 'package:gubify/modules/moderation/blocking/services/user_block_service.dart';

void main() {
  group('UserBlockService', () {
    test('blocks another user for the authenticated account', () async {
      final repository = _FakeUserBlockRepository();
      final service = UserBlockService.forTesting(
        currentUserId: () => 'user-a',
        repository: repository,
      );

      await service.blockUser(' user-b ');

      expect(repository.blockCalls, [('user-a', 'user-b')]);
    });

    test('rejects self-block before writing', () async {
      final repository = _FakeUserBlockRepository();
      final service = UserBlockService.forTesting(
        currentUserId: () => 'user-a',
        repository: repository,
      );

      await expectLater(service.blockUser('user-a'), throwsArgumentError);
      expect(repository.blockCalls, isEmpty);
    });

    test('rejects an empty target UID before writing', () async {
      final repository = _FakeUserBlockRepository();
      final service = UserBlockService.forTesting(
        currentUserId: () => 'user-a',
        repository: repository,
      );

      await expectLater(service.blockUser('  '), throwsArgumentError);
      expect(repository.blockCalls, isEmpty);
    });

    test('delegates unblock for the authenticated account', () async {
      final repository = _FakeUserBlockRepository();
      final service = UserBlockService.forTesting(
        currentUserId: () => 'user-a',
        repository: repository,
      );

      await service.unblockUser('user-b');

      expect(repository.unblockCalls, [('user-a', 'user-b')]);
    });

    test('maps an absent block document to false', () async {
      final repository = _FakeUserBlockRepository.absentBlock();
      final service = UserBlockService.forTesting(
        currentUserId: () => 'user-a',
        repository: repository,
      );

      final blocked = await service.isUserBlockedStream('user-b').first;

      expect(blocked, isFalse);
    });

    test('maps an existing block document to true', () async {
      final repository = _FakeUserBlockRepository();
      final service = UserBlockService.forTesting(
        currentUserId: () => 'user-a',
        repository: repository,
      );

      final result = service.isUserBlockedStream('user-b').first;
      repository.blockController.add(
        const UserBlockModel(blockedUserId: 'user-b', blockedAt: null),
      );
      final blocked = await result;

      expect(blocked, isTrue);
    });

    test('exposes the authenticated account block list', () async {
      final repository = _FakeUserBlockRepository();
      final service = UserBlockService.forTesting(
        currentUserId: () => 'user-a',
        repository: repository,
      );

      final result = service.blockedUsersStream().first;
      repository.listController.add([
        UserBlockModel(
          blockedUserId: 'user-b',
          blockedAt: Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        ),
      ]);
      final blocks = await result;

      expect(blocks.single.blockedUserId, 'user-b');
      expect(repository.lastListUserId, 'user-a');
    });
  });
}

class _FakeUserBlockRepository implements UserBlockRepository {
  _FakeUserBlockRepository() : _initialBlockStream = null;

  _FakeUserBlockRepository.absentBlock()
    : _initialBlockStream = Stream.value(null);

  final blockCalls = <(String, String)>[];
  final unblockCalls = <(String, String)>[];
  final Stream<UserBlockModel?>? _initialBlockStream;
  final blockController = StreamController<UserBlockModel?>.broadcast();
  final listController = StreamController<List<UserBlockModel>>.broadcast();
  String? lastListUserId;

  @override
  Future<void> blockUser({
    required String blockerUserId,
    required String blockedUserId,
  }) async {
    blockCalls.add((blockerUserId, blockedUserId));
  }

  @override
  Stream<UserBlockModel?> blockStream({
    required String blockerUserId,
    required String blockedUserId,
  }) => _initialBlockStream ?? blockController.stream;

  @override
  Stream<List<UserBlockModel>> blockedUsersStream({
    required String blockerUserId,
  }) {
    lastListUserId = blockerUserId;
    return listController.stream;
  }

  @override
  Future<void> unblockUser({
    required String blockerUserId,
    required String blockedUserId,
  }) async {
    unblockCalls.add((blockerUserId, blockedUserId));
  }
}
