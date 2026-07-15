import 'package:flutter/material.dart';

import '../models/proposal_model.dart';
import '../screens/proposal_details_screen.dart';

class ProposalCard extends StatelessWidget {
  final ProposalModel proposal;

  const ProposalCard({
    super.key,
    required this.proposal,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProposalDetailsScreen(
              proposal: proposal,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const Icon(
            Icons.how_to_vote,
            color: Colors.blue,
          ),
          title: Text(
            proposal.title,
          ),
          subtitle: Text(
            proposal.status,
          ),
          trailing: Text(
            "${proposal.yesVotes} 👍  ${proposal.noVotes} 👎",
          ),
        ),
      ),
    );
  }
}