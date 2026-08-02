import 'package:flutter/material.dart';

import '../../../core/models/creation_availability.dart';
import '../../../core/navigation/creation_gate.dart';
import '../models/proposal_model.dart';
import '../screens/create_proposal_screen.dart';
import '../screens/proposal_details_screen.dart';
import '../services/proposal_service.dart';

class ProposalHomeCard extends StatelessWidget {
  final String gubId;
  final int memberCount;

  const ProposalHomeCard({
    super.key,
    required this.gubId,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProposalModel>>(
      stream: ProposalService.instance.proposalsStream(gubId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final proposals = snapshot.data!;

        ProposalModel? activeProposal;

        for (final proposal in proposals) {
          if (proposal.status == "voting") {
            activeProposal = proposal;
            break;
          }
        }

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            if (activeProposal == null) {
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
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProposalDetailsScreen(proposal: activeProposal!),
                ),
              );
            }
          },
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.how_to_vote, color: Colors.blue),
                      SizedBox(width: 10),
                      Text(
                        "Proposals",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (activeProposal == null) ...[
                    const Text(
                      "No active proposals",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text("Create your first proposal for this Hub."),
                  ] else ...[
                    Text(
                      activeProposal.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      activeProposal.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        const Icon(
                          Icons.thumb_up,
                          color: Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(activeProposal.yesVotes.toString()),

                        const SizedBox(width: 18),

                        const Icon(
                          Icons.thumb_down,
                          color: Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(activeProposal.noVotes.toString()),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
