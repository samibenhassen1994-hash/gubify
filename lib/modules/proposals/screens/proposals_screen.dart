import 'package:flutter/material.dart';

import '../services/proposal_service.dart';
import '../models/proposal_model.dart';
import '../widgets/proposal_card.dart';
import 'create_proposal_screen.dart';

class ProposalsScreen extends StatelessWidget {
  final String hubId;
  final int memberCount;

  const ProposalsScreen({
    super.key,
    required this.hubId,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Proposals"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("Proposal"),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateProposalScreen(
                hubId: hubId,
                memberCount: memberCount,
              ),
            ),
          );
        },
      ),
      body: StreamBuilder<List<ProposalModel>>(
        stream: ProposalService.instance
            .proposalsStream(hubId),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "No proposals yet.",
              ),
            );
          }

          final proposals = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: proposals.length,
            itemBuilder: (context, index) {
              return ProposalCard(
                proposal: proposals[index],
              );
            },
          );
        },
      ),
    );
  }
}