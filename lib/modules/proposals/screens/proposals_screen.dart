import 'package:flutter/material.dart';

import '../../../core/models/creation_availability.dart';
import '../../../core/navigation/creation_gate.dart';
import '../../../widgets/gub_screen_background.dart';
import '../services/proposal_service.dart';
import '../models/proposal_model.dart';
import '../widgets/proposal_card.dart';
import 'create_proposal_screen.dart';

class ProposalsScreen extends StatelessWidget {
  final String gubId;
  final int memberCount;

  const ProposalsScreen({
    super.key,
    required this.gubId,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.proposals,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Proposals"),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text("Create Proposal"),
          onPressed: () async {
            final allowed = await CreationGate.ensureAvailable(
              context: context,
              gubId: gubId,
              moduleType: CreationModuleType.proposal,
            );
            if (!allowed || !context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateProposalScreen(
                  gubId: gubId,
                  memberCount: memberCount,
                ),
              ),
            );
          },
        ),
        body: StreamBuilder<List<ProposalModel>>(
          stream: ProposalService.instance.proposalsStream(gubId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("No proposals yet."));
            }

            final proposals = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: proposals.length,
              itemBuilder: (context, index) {
                return ProposalCard(proposal: proposals[index]);
              },
            );
          },
        ),
      ),
    );
  }
}
