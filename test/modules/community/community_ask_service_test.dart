import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/repositories/community_ask_repository.dart';
import 'package:gubify/modules/community/services/community_ask_service.dart';

void main() {
  test('linked account delegates own-message ask creation', () async {
    String? capturedCommunityId;
    String? capturedSourceMessageId;
    CommunityAskType? capturedType;
    final service = CommunityAskService.forTesting(
      currentAccount: () =>
          const CommunityAskAccount(userId: 'user-1', isAnonymous: false),
      createAskFromMessage:
          ({
            required communityId,
            required sourceMessageId,
            required type,
            required authorId,
          }) async {
            capturedCommunityId = communityId;
            capturedSourceMessageId = sourceMessageId;
            capturedType = type;
            expect(authorId, 'user-1');
            return CommunityAskCreateResult.created;
          },
    );

    await service.createAskFromMessage(
      communityId: ' community-1 ',
      sourceMessageId: ' message-1 ',
      type: CommunityAskType.information,
    );

    expect(capturedCommunityId, 'community-1');
    expect(capturedSourceMessageId, 'message-1');
    expect(capturedType, CommunityAskType.information);
  });

  test('anonymous account is rejected before repository mutation', () async {
    var repositoryCalled = false;
    final service = CommunityAskService.forTesting(
      currentAccount: () =>
          const CommunityAskAccount(userId: 'anonymous-1', isAnonymous: true),
      createAskFromMessage:
          ({
            required communityId,
            required sourceMessageId,
            required type,
            required authorId,
          }) async {
            repositoryCalled = true;
            return CommunityAskCreateResult.created;
          },
    );

    expect(
      () => service.createAskFromMessage(
        communityId: 'community-1',
        sourceMessageId: 'message-1',
        type: CommunityAskType.help,
      ),
      throwsA(isA<CommunityAskLinkedAccountException>()),
    );
    expect(repositoryCalled, isFalse);
  });

  test('duplicate result becomes a friendly application exception', () async {
    final service = CommunityAskService.forTesting(
      currentAccount: () =>
          const CommunityAskAccount(userId: 'user-1', isAnonymous: false),
      createAskFromMessage:
          ({
            required communityId,
            required sourceMessageId,
            required type,
            required authorId,
          }) async => CommunityAskCreateResult.duplicate,
    );

    expect(
      () => service.createAskFromMessage(
        communityId: 'community-1',
        sourceMessageId: 'message-1',
        type: CommunityAskType.advice,
      ),
      throwsA(isA<CommunityAskAlreadyExistsException>()),
    );
  });

  test('not-author result remains protected at service level', () async {
    final service = CommunityAskService.forTesting(
      currentAccount: () =>
          const CommunityAskAccount(userId: 'user-1', isAnonymous: false),
      createAskFromMessage:
          ({
            required communityId,
            required sourceMessageId,
            required type,
            required authorId,
          }) async => CommunityAskCreateResult.notAuthor,
    );

    expect(
      () => service.createAskFromMessage(
        communityId: 'community-1',
        sourceMessageId: 'message-1',
        type: CommunityAskType.help,
      ),
      throwsA(isA<CommunityAskNotAllowedException>()),
    );
  });

  test('active ask stream is scoped only by Community and author', () async {
    String? capturedCommunityId;
    String? capturedAuthorId;
    final service = CommunityAskService.forTesting(
      currentAccount: () =>
          const CommunityAskAccount(userId: 'viewer-1', isAnonymous: false),
      createAskFromMessage:
          ({
            required communityId,
            required sourceMessageId,
            required type,
            required authorId,
          }) async => CommunityAskCreateResult.created,
      activeAsks: ({required communityId, required authorId}) {
        capturedCommunityId = communityId;
        capturedAuthorId = authorId;
        return Stream.value(const []);
      },
    );

    await service
        .activeAsksStream(communityId: ' community-1 ', authorId: ' author-1 ')
        .first;

    expect(capturedCommunityId, 'community-1');
    expect(capturedAuthorId, 'author-1');
  });

  test('board stream and one-shot count normalize the Community id', () async {
    String? streamCommunityId;
    String? countCommunityId;
    final service = CommunityAskService.forTesting(
      currentAccount: () =>
          const CommunityAskAccount(userId: 'viewer-1', isAnonymous: false),
      createAskFromMessage:
          ({
            required communityId,
            required sourceMessageId,
            required type,
            required authorId,
          }) async => CommunityAskCreateResult.created,
      watchActiveAsks: ({required communityId}) {
        streamCommunityId = communityId;
        return Stream.value(const []);
      },
      getActiveAskCount: ({required communityId}) async {
        countCommunityId = communityId;
        return 4;
      },
    );

    await service.watchActiveAsks(' community-1 ').first;
    final count = await service.getActiveAskCount(' community-1 ');

    expect(streamCommunityId, 'community-1');
    expect(countCommunityId, 'community-1');
    expect(count, 4);
  });

  for (final type in CommunityAskType.values) {
    test('Direct ${type.label} ask uses normalized text and current name', () async {
      String? capturedText;
      String? capturedName;
      CommunityAskType? capturedType;
      final service = CommunityAskService.forTesting(
        currentAccount: () =>
            const CommunityAskAccount(userId: 'user-1', isAnonymous: false),
        currentDisplayName: () async => 'Current Sami',
        createAskFromMessage:
            ({
              required communityId,
              required sourceMessageId,
              required type,
              required authorId,
            }) async => CommunityAskCreateResult.created,
        createDirectAsk:
            ({
              required communityId,
              required text,
              required type,
              required authorId,
              required authorDisplayName,
            }) async {
              expect(communityId, 'community-1');
              expect(authorId, 'user-1');
              capturedText = text;
              capturedName = authorDisplayName;
              capturedType = type;
              return 'generated-id';
            },
      );

      final askId = await service.createDirectAsk(
        communityId: ' community-1 ',
        text: '  A direct question  ',
        type: type,
      );

      expect(askId, 'generated-id');
      expect(capturedText, 'A direct question');
      expect(capturedName, 'Current Sami');
      expect(capturedType, type);
    });
  }

  test('Direct ask rejects blank and over-limit text before repository', () async {
    var repositoryCalls = 0;
    final service = CommunityAskService.forTesting(
      currentAccount: () =>
          const CommunityAskAccount(userId: 'user-1', isAnonymous: false),
      currentDisplayName: () async => 'Sami',
      createAskFromMessage:
          ({
            required communityId,
            required sourceMessageId,
            required type,
            required authorId,
          }) async => CommunityAskCreateResult.created,
      createDirectAsk:
          ({
            required communityId,
            required text,
            required type,
            required authorId,
            required authorDisplayName,
          }) async {
            repositoryCalls++;
            return 'generated-id';
          },
    );

    expect(
      () => service.createDirectAsk(
        communityId: 'community-1',
        text: '   ',
        type: CommunityAskType.help,
      ),
      throwsArgumentError,
    );
    expect(
      () => service.createDirectAsk(
        communityId: 'community-1',
        text: List.filled(CommunityAskService.maxTextLength + 1, 'x').join(),
        type: CommunityAskType.help,
      ),
      throwsArgumentError,
    );
    expect(repositoryCalls, 0);
  });
}
