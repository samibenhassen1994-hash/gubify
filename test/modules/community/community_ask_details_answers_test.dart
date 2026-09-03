import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_ask_answer_model.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/screens/community_ask_details_screen.dart';
import 'package:gubify/modules/community/repositories/community_ask_answer_repository.dart';
import 'package:gubify/modules/community/services/community_ask_answer_service.dart';
import 'package:gubify/modules/community/services/community_ask_service.dart';
import 'package:gubify/modules/community/services/community_user_xp_cache.dart';

final _xpCache = CommunityUserXpCache(loadXp: (_) async => const {});

CommunityAskModel _ask({
  CommunityAskStatus status = CommunityAskStatus.active,
  String? bestAnswerId,
  Timestamp? updatedAt,
}) => CommunityAskModel(
  askId: 'ask-1',
  communityId: 'community-1',
  authorId: 'asker',
  authorDisplayName: 'Asker',
  type: CommunityAskType.help,
  text: 'How can I solve this?',
  createdAt: Timestamp(1, 0),
  updatedAt: updatedAt,
  status: status,
  bestAnswerId: bestAnswerId,
  bestAnswerAuthorId: bestAnswerId == null ? null : 'winner',
  resolvedAt: bestAnswerId == null ? null : Timestamp(4, 0),
  xpAwarded: bestAnswerId != null,
);

final answers = [
  CommunityAskAnswerModel(
    answerId: 'asker',
    authorId: 'asker',
    authorDisplayName: 'Asker',
    text: 'My own follow-up',
    createdAt: Timestamp(2, 0),
  ),
  CommunityAskAnswerModel(
    answerId: 'best',
    authorId: 'winner',
    authorDisplayName: 'Winner',
    text: 'The winning answer',
    createdAt: Timestamp(3, 0),
  ),
];

Widget _details({
  CommunityAskModel? ask,
  CommunityAskStatus status = CommunityAskStatus.active,
  String? bestAnswerId,
  String currentUserId = 'asker',
  List<CommunityAskAnswerModel>? answersData,
  Future<void> Function(String text)? onCreate,
  Future<void> Function(CommunityAskAnswerModel answer)? onSelect,
  Future<void> Function(CommunityAskAnswerModel answer, String text)? onEdit,
  Future<void> Function(String text)? onEditAsk,
  void Function(String userId)? onOpenProfile,
  CommunityUserXpCache? membershipXpCache,
  CommunityAskAnswerService? answerService,
  Stream<CommunityAskModel?>? askStream,
  Stream<List<CommunityAskAnswerModel>>? answersStream,
}) {
  final askValue = ask ?? _ask(status: status, bestAnswerId: bestAnswerId);
  return MaterialApp(
    home: CommunityAskDetailsScreen(
      ask: askValue,
      communityName: 'Community',
      askStream: askStream ?? Stream.value(askValue),
      answersStream: answersStream ?? Stream.value(answersData ?? answers),
      currentUserId: currentUserId,
      onCreateAnswer: onCreate,
      onSelectBestAnswer: onSelect,
      onEditAnswer: onEdit,
      onEditAsk: onEditAsk,
      onOpenProfile: onOpenProfile,
      membershipXpCache: membershipXpCache ?? _xpCache,
      answerService: answerService,
    ),
  );
}

void main() {
  testWidgets('Ask and Answer avatars render levels from the shared XP map', (
    tester,
  ) async {
    final levelCache = CommunityUserXpCache(
      loadXp: (_) async => const {'asker': 640, 'winner': 900},
    );
    await tester.pumpWidget(
      _details(bestAnswerId: 'best', membershipXpCache: levelCache),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lv 8'), findsNWidgets(2));
    expect(find.text('Lv 10'), findsOneWidget);
  });

  testWidgets(
    'active Ask replaces the second composer with the current user Answer state',
    (tester) async {
      await tester.pumpWidget(
        _details(
          currentUserId: 'member',
          answersData: [
            CommunityAskAnswerModel(
              answerId: 'member',
              authorId: 'member',
              authorDisplayName: 'Member',
              text: 'My existing answer',
              createdAt: Timestamp(2, 0),
            ),
            answers.last,
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('You have already answered this Ask.'),
        200,
      );
      await tester.pumpAndSettle();
      expect(find.text('Answers'), findsOneWidget);
      expect(find.text('Answers · 2'), findsNothing);
      expect(find.byKey(const ValueKey('answer-composer')), findsNothing);
      expect(find.text('You have already answered this Ask.'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    },
  );

  testWidgets('non-author cannot select Best Answer', (tester) async {
    await tester.pumpWidget(_details(currentUserId: 'winner'));
    await tester.pumpAndSettle();
    expect(find.text('Select best'), findsNothing);
  });

  testWidgets('Ask author without an Answer does not see the composer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _details(answersData: const <CommunityAskAnswerModel>[]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('answer-composer')), findsNothing);
  });

  testWidgets('edited Answer shows its label and no longer offers Edit', (
    tester,
  ) async {
    await tester.pumpWidget(
      _details(
        currentUserId: 'member',
        answersData: [
          CommunityAskAnswerModel(
            answerId: 'member',
            authorId: 'member',
            authorDisplayName: 'Member',
            text: 'Edited once',
            createdAt: Timestamp(2, 0),
            updatedAt: Timestamp(3, 0),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Edited'), 200);

    expect(find.text('Edited'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets(
    'Ask author keeps Select best and Delete in one compact action group',
    (tester) async {
      await tester.pumpWidget(_details());
      await tester.pumpAndSettle();

      final actionGroup = find.ancestor(
        of: find.text('Select best'),
        matching: find.byType(Wrap),
      );
      expect(actionGroup, findsOneWidget);
      expect(
        find.descendant(of: actionGroup, matching: find.text('Delete')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Ask author edits an active Ask with the stateful dialog', (
    tester,
  ) async {
    String? editedText;
    await tester.pumpWidget(
      _details(onEditAsk: (text) async => editedText = text),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit Ask'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Ask'), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), 'Updated Ask');
    final dialog = find.byType(AlertDialog);
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextButton, 'Save'),
      ),
    );
    await tester.pumpAndSettle();

    expect(editedText, 'Updated Ask');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'updated Ask shows its existing timestamp without an extra read',
    (tester) async {
      await tester.pumpWidget(
        _details(ask: _ask(updatedAt: Timestamp(1725126300, 0))),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Edited '), findsOneWidget);
    },
  );

  testWidgets('Answer composer blocks whitespace and clears after success', (
    tester,
  ) async {
    String? submitted;
    await tester.pumpWidget(
      _details(
        currentUserId: 'new-answerer',
        answersData: answers
            .where((answer) => answer.authorId != 'new-answerer')
            .toList(),
        onCreate: (text) async => submitted = text,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('answer-input')), '   ');
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('answer-send')))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey('answer-input')),
      '  Useful answer  ',
    );
    await tester.pump();
    final send = find.byKey(const ValueKey('answer-send'));
    await tester.ensureVisible(send);
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(submitted, 'Useful answer');
    expect(find.text('Useful answer'), findsNothing);
  });

  testWidgets('author identity opens the selected Community profile callback', (
    tester,
  ) async {
    String? openedUserId;
    await tester.pumpWidget(
      _details(onOpenProfile: (userId) => openedUserId = userId),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ask-detail-author-ask-1')));
    expect(openedUserId, 'asker');
    await tester.tap(find.byKey(const ValueKey('answer-author-best')));
    expect(openedUserId, 'winner');
  });

  testWidgets('Select best requires confirmation', (tester) async {
    CommunityAskAnswerModel? selected;
    await tester.pumpWidget(
      _details(onSelect: (answer) async => selected = answer),
    );
    await tester.pumpAndSettle();
    final selectBest = find.text('Select best');
    await tester.ensureVisible(selectBest);
    await tester.pumpAndSettle();
    await tester.tap(selectBest);
    await tester.pumpAndSettle();

    expect(find.text('Select best answer?'), findsOneWidget);
    expect(
      find.text('This will resolve the ask and close the topic.'),
      findsOneWidget,
    );
    final dialog = find.byType(AlertDialog);
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextButton, 'Select best'),
      ),
    );
    await tester.pumpAndSettle();
    expect(selected?.answerId, 'best');
  });

  testWidgets(
    'Select best updates Details avatars through its injected shared XP cache',
    (tester) async {
      var loads = 0;
      final cache = CommunityUserXpCache(
        loadXp: (_) async {
          loads++;
          return const {'asker': 10, 'winner': 40};
        },
      );
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
              result: CommunityAskResolveResult.resolved,
              xpByUserId: {'asker': 12, 'winner': 60},
            ),
        primeXp: cache.prime,
      );
      await tester.pumpWidget(
        _details(membershipXpCache: cache, answerService: service),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lv 2'), findsOneWidget);
      final loadsBeforeReward = loads;

      final selectBest = find.text('Select best');
      await tester.ensureVisible(selectBest);
      await tester.pumpAndSettle();
      await tester.tap(selectBest);
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(TextButton, 'Select best'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lv 3'), findsOneWidget);
      final lease = cache.acquire({'asker', 'winner'});
      addTearDown(lease.release);
      expect(await lease.stream.first, {'asker': 12, 'winner': 60});
      expect(loads, loadsBeforeReward);
    },
  );

  testWidgets(
    'Select best immediately renders the confirmed resolved state without an Ask snapshot',
    (tester) async {
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
              result: CommunityAskResolveResult.resolved,
              xpByUserId: {'asker': 12, 'winner': 60},
            ),
      );
      await tester.pumpWidget(
        _details(askStream: Stream.value(_ask()), answerService: service),
      );
      await tester.pumpAndSettle();

      final selectBest = find.text('Select best');
      await tester.ensureVisible(selectBest);
      await tester.pumpAndSettle();
      await tester.tap(selectBest);
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(TextButton, 'Select best'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resolved'), findsWidgets);
      expect(find.text('✓ Best answer'), findsOneWidget);
      expect(find.text('Select best'), findsNothing);
      expect(find.text('This ask has been resolved.'), findsOneWidget);
    },
  );

  testWidgets('failed Best Answer selection keeps the active Answer state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _details(onSelect: (_) async => throw StateError('transaction failed')),
    );
    await tester.pumpAndSettle();

    final selectBest = find.text('Select best');
    await tester.ensureVisible(selectBest);
    await tester.pumpAndSettle();
    await tester.tap(selectBest);
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextButton, 'Select best'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('✓ Best answer'), findsNothing);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Select best'), findsOneWidget);
  });

  testWidgets(
    'Select best shows loading and prevents a concurrent selection until success',
    (tester) async {
      final resolution = Completer<CommunityAskResolution>();
      var resolveCalls = 0;
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
            }) {
              resolveCalls++;
              return resolution.future;
            },
      );
      final secondAnswer = CommunityAskAnswerModel(
        answerId: 'second',
        authorId: 'second',
        authorDisplayName: 'Second',
        text: 'Another answer',
        createdAt: Timestamp(4, 0),
      );
      await tester.pumpWidget(
        _details(
          answersData: [answers.last, secondAnswer],
          answerService: service,
        ),
      );
      await tester.pumpAndSettle();

      final firstSelect = find.text('Select best').first;
      await tester.ensureVisible(firstSelect);
      await tester.pumpAndSettle();
      await tester.tap(firstSelect);
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(TextButton, 'Select best'),
        ),
      );
      await tester.pump();

      expect(find.text('Selecting...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('✓ Best answer'), findsNothing);
      expect(find.text('Resolved'), findsNothing);
      expect(resolveCalls, 1);
      final disabledOtherSelect = find.byWidgetPredicate(
        (widget) =>
            widget is TextButton &&
            widget.onPressed == null &&
            widget.child is Text &&
            (widget.child as Text).data == 'Select best',
      );
      expect(disabledOtherSelect, findsOneWidget);

      resolution.complete(
        const CommunityAskResolution(
          result: CommunityAskResolveResult.resolved,
          bestAnswerId: 'best',
          bestAnswerAuthorId: 'winner',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Selecting...'), findsNothing);
      expect(find.text('✓ Best answer'), findsOneWidget);
      expect(find.text('Resolved'), findsWidgets);
      expect(resolveCalls, 1);
    },
  );

  testWidgets('failed Best Answer selection restores its normal action', (
    tester,
  ) async {
    final pending = Completer<void>();
    await tester.pumpWidget(_details(onSelect: (_) => pending.future));
    await tester.pumpAndSettle();

    final selectBest = find.text('Select best');
    await tester.ensureVisible(selectBest);
    await tester.pumpAndSettle();
    await tester.tap(selectBest);
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextButton, 'Select best'),
      ),
    );
    await tester.pump();

    expect(find.text('Selecting...'), findsOneWidget);
    pending.completeError(StateError('transaction failed'));
    await tester.pumpAndSettle();

    expect(find.text('Selecting...'), findsNothing);
    expect(find.text('Select best'), findsOneWidget);
    expect(find.text('✓ Best answer'), findsNothing);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('own Answer edit closes cleanly after saving', (tester) async {
    CommunityAskAnswerModel? editedAnswer;
    String? editedText;
    await tester.pumpWidget(
      _details(
        onEdit: (answer, text) async {
          editedAnswer = answer;
          editedText = text;
        },
      ),
    );
    await tester.pumpAndSettle();

    final edit = find.text('Edit');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.text('Edit Answer'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Updated Answer');
    final dialog = find.byType(AlertDialog);
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextButton, 'Save'),
      ),
    );
    await tester.pumpAndSettle();

    expect(editedAnswer?.answerId, 'asker');
    expect(editedText, 'Updated Answer');
    expect(tester.takeException(), isNull);
  });

  testWidgets('resolved Ask pins Best Answer and removes composer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _details(status: CommunityAskStatus.resolved, bestAnswerId: 'best'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resolved'), findsWidgets);
    expect(find.text('✓ Best answer'), findsOneWidget);
    expect(find.byKey(const ValueKey('answer-composer')), findsNothing);
    expect(find.text('Select best'), findsNothing);
    expect(
      tester.getTopLeft(find.text('The winning answer')).dy,
      lessThan(tester.getTopLeft(find.text('My own follow-up')).dy),
    );
  });
}
