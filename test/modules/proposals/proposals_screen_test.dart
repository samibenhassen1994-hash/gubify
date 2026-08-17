import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/proposals/models/proposal_model.dart';
import 'package:gubify/modules/proposals/repositories/proposal_repository.dart';
import 'package:gubify/modules/proposals/screens/proposals_screen.dart';
import 'package:gubify/screens/gub/widgets/gub_dashboard_section.dart';

void main() {
  ProposalModel proposal(String id, {int yesVotes = 0}) => ProposalModel(
    gubId: 'gub',
    proposalId: id,
    title: 'Proposal $id',
    description: 'Description $id',
    creatorId: 'creator-$id',
    creatorName: 'Creator $id',
    status: 'voting',
    createdAt: Timestamp(1, 0),
    expiresAt: Timestamp(2, 0),
    type: 'custom',
    yesVotes: yesVotes,
    noVotes: 0,
    memberCount: 3,
    resultProcessed: false,
    eventCreated: false,
    tasksCreated: false,
  );

  test('vote documents are isolated by proposalId', () {
    final first = ProposalRepository.voteDocumentPath(
      gubId: 'gub',
      proposalId: 'one',
      uid: 'member',
    );
    final second = ProposalRepository.voteDocumentPath(
      gubId: 'gub',
      proposalId: 'two',
      uid: 'member',
    );

    expect(first, 'gubs/gub/proposals/one/votes/member');
    expect(second, 'gubs/gub/proposals/two/votes/member');
    expect(first, isNot(second));
  });

  test('dashboard active proposal access opens the complete list', () {
    final destination = GubDashboardSection.proposalDestination(
      activeProposal: proposal('one'),
      gubId: 'gub',
      memberCount: 3,
    );

    expect(destination, isA<ProposalsScreen>());
  });

  testWidgets('all active proposals remain visible after one vote updates', (
    tester,
  ) async {
    final proposals = StreamController<List<ProposalModel>>();
    addTearDown(proposals.close);
    await tester.pumpWidget(
      MaterialApp(
        home: ProposalsScreen(
          gubId: 'gub',
          memberCount: 3,
          proposals: proposals.stream,
        ),
      ),
    );

    proposals.add([proposal('one'), proposal('two')]);
    await tester.pump();
    expect(find.text('Proposal one'), findsOneWidget);
    expect(find.text('Proposal two'), findsOneWidget);

    proposals.add([proposal('one', yesVotes: 1), proposal('two')]);
    await tester.pump();
    expect(find.text('Proposal one'), findsOneWidget);
    expect(find.text('Proposal two'), findsOneWidget);
    expect(find.text('1 👍  0 👎'), findsOneWidget);
  });
}
