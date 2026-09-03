import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_ask_answer_model.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/repositories/community_ask_answer_repository.dart';
import 'package:gubify/modules/community/services/community_ask_answer_service.dart';
import 'package:gubify/modules/community/services/community_ask_service.dart';

CommunityAskModel _ask({
  CommunityAskStatus status = CommunityAskStatus.active,
}) => CommunityAskModel(
  askId: 'ask-1',
  communityId: 'community-1',
  authorId: 'asker',
  authorDisplayName: 'Asker',
  type: CommunityAskType.help,
  text: 'Question',
  createdAt: Timestamp(1, 0),
  status: status,
);

CommunityAskAnswerModel _answer({String authorId = 'winner'}) =>
    CommunityAskAnswerModel(
      answerId: authorId,
      authorId: authorId,
      authorDisplayName: 'Winner',
      text: 'Answer',
      createdAt: Timestamp(2, 0),
    );

void main() {
  test('linked member creates a trimmed Answer with cached identity', () async {
    String? text;
    String? displayName;
    String? createdAuthorId;
    final service = CommunityAskAnswerService.forTesting(
      currentAccount: () =>
          const CommunityAskAccount(userId: 'member', isAnonymous: false),
      currentDisplayName: () async => ' Current Member ',
      createAnswer:
          ({
            required communityId,
            required askId,
            required authorId,
            required askAuthorId,
            required authorDisplayName,
            required answerText,
          }) async {
            createdAuthorId = authorId;
            text = answerText;
            displayName = authorDisplayName;
            return CommunityAnswerCreateResult.created;
          },
    );

    final id = await service.createAnswer(
      communityId: 'community-1',
      askId: 'ask-1',
      askAuthorId: 'asker',
      text: '  Try this  ',
      askStatus: CommunityAskStatus.active,
    );

    expect(id, 'member');
    expect(createdAuthorId, 'member');
    expect(text, 'Try this');
    expect(displayName, 'Current Member');
  });

  test('Ask author cannot create an Answer on their own Ask', () async {
    var calls = 0;
    final service = CommunityAskAnswerService.forTesting(
      currentAccount: () =>
          const CommunityAskAccount(userId: 'asker', isAnonymous: false),
      currentDisplayName: () async => 'Asker',
      createAnswer:
          ({
            required communityId,
            required askId,
            required authorId,
            required askAuthorId,
            required authorDisplayName,
            required answerText,
          }) async {
            calls++;
            return CommunityAnswerCreateResult.created;
          },
    );

    await expectLater(
      service.createAnswer(
        communityId: 'community-1',
        askId: 'ask-1',
        askAuthorId: 'asker',
        text: 'My own answer',
        askStatus: CommunityAskStatus.active,
      ),
      throwsA(isA<CommunityAskAuthorCannotAnswerException>()),
    );
    expect(calls, 0);
  });

  test(
    'blank and resolved Answer creation are blocked before repository',
    () async {
      var calls = 0;
      final service = CommunityAskAnswerService.forTesting(
        currentAccount: () =>
            const CommunityAskAccount(userId: 'member', isAnonymous: false),
        currentDisplayName: () async => 'Member',
        createAnswer:
            ({
              required communityId,
              required askId,
              required authorId,
              required askAuthorId,
              required authorDisplayName,
              required answerText,
            }) async {
              calls++;
              return CommunityAnswerCreateResult.created;
            },
      );

      await expectLater(
        service.createAnswer(
          communityId: 'community-1',
          askId: 'ask-1',
          askAuthorId: 'asker',
          text: '   ',
          askStatus: CommunityAskStatus.active,
        ),
        throwsArgumentError,
      );
      await expectLater(
        service.createAnswer(
          communityId: 'community-1',
          askId: 'ask-1',
          askAuthorId: 'asker',
          text: 'Answer',
          askStatus: CommunityAskStatus.resolved,
        ),
        throwsA(isA<CommunityAskResolvedException>()),
      );
      expect(calls, 0);
    },
  );

  test('second Answer edit is blocked before the repository', () async {
    var edits = 0;
    final service = CommunityAskAnswerService.forTesting(
      currentAccount: () =>
          const CommunityAskAccount(userId: 'member', isAnonymous: false),
      currentDisplayName: () async => 'Member',
      createAnswer:
          ({
            required communityId,
            required askId,
            required authorId,
            required askAuthorId,
            required authorDisplayName,
            required answerText,
          }) async => CommunityAnswerCreateResult.created,
      editAnswer:
          ({
            required communityId,
            required askId,
            required answerId,
            required text,
            required hasBeenEdited,
          }) async {
            edits++;
            return CommunityAnswerEditResult.edited;
          },
    );
    final alreadyEdited = CommunityAskAnswerModel(
      answerId: 'member',
      authorId: 'member',
      authorDisplayName: 'Member',
      text: 'Edited once',
      createdAt: Timestamp(2, 0),
      updatedAt: Timestamp(3, 0),
    );

    await expectLater(
      service.editAnswer(
        ask: _ask(),
        answer: alreadyEdited,
        text: 'Edited twice',
      ),
      throwsA(isA<CommunityAnswerAlreadyEditedException>()),
    );
    expect(edits, 0);
  });

  test(
    'only asker selects another member Answer and reward is single-shot',
    () async {
      var calls = 0;
      Map<String, int>? primedXp;
      final service = CommunityAskAnswerService.forTesting(
        currentAccount: () =>
            const CommunityAskAccount(userId: 'asker', isAnonymous: false),
        currentDisplayName: () async => 'Asker',
        createAnswer:
            ({
              required communityId,
              required askId,
              required authorId,
              required askAuthorId,
              required authorDisplayName,
              required answerText,
            }) async => CommunityAnswerCreateResult.created,
        resolveAsk:
            ({
              required communityId,
              required askId,
              required answerId,
              required resolverId,
            }) async {
              calls++;
              return const CommunityAskResolution(
                result: CommunityAskResolveResult.resolved,
                xpByUserId: {'winner': 120, 'asker': 42},
              );
            },
        primeXp: (value) => primedXp = value,
      );

      await service.selectBestAnswer(ask: _ask(), answer: _answer());
      expect(calls, 1);
      expect(primedXp, {'winner': 120, 'asker': 42});

      await expectLater(
        service.selectBestAnswer(
          ask: _ask(status: CommunityAskStatus.resolved),
          answer: _answer(),
        ),
        throwsA(isA<CommunityAskResolvedException>()),
      );
      await expectLater(
        service.selectBestAnswer(
          ask: _ask(),
          answer: _answer(authorId: 'asker'),
        ),
        throwsA(isA<CommunityAskOwnAnswerException>()),
      );
      expect(calls, 1);
    },
  );

  test(
    'removed Answer author produces a controlled ineligible error',
    () async {
      final service = CommunityAskAnswerService.forTesting(
        currentAccount: () =>
            const CommunityAskAccount(userId: 'asker', isAnonymous: false),
        currentDisplayName: () async => 'Asker',
        createAnswer:
            ({
              required communityId,
              required askId,
              required authorId,
              required askAuthorId,
              required authorDisplayName,
              required answerText,
            }) async => CommunityAnswerCreateResult.created,
        resolveAsk:
            ({
              required communityId,
              required askId,
              required answerId,
              required resolverId,
            }) async => const CommunityAskResolution(
              result: CommunityAskResolveResult.winnerNotMember,
            ),
      );

      await expectLater(
        service.selectBestAnswer(ask: _ask(), answer: _answer()),
        throwsA(isA<CommunityAskWinnerNotMemberException>()),
      );
    },
  );
}
