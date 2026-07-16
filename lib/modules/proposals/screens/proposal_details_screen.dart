import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/proposal_model.dart';
import '../services/proposal_service.dart';

class ProposalDetailsScreen extends StatelessWidget {
  final ProposalModel proposal;

  const ProposalDetailsScreen({super.key, required this.proposal});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<ProposalModel?>(
      stream: ProposalService.instance.proposalStream(
        hubId: proposal.hubId,
        proposalId: proposal.proposalId,
      ),
      builder: (context, proposalSnapshot) {
        if (proposalSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (proposalSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Proposal')),
            body: Center(
              child: Text(
                'Error: ${proposalSnapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final p = proposalSnapshot.data;

        if (p == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Proposal')),
            body: const Center(
              child: Text('Proposal not found or has been deleted.'),
            ),
          );
        }

        return StreamBuilder<String?>(
          stream: ProposalService.instance.userVoteStream(
            hubId: p.hubId,
            proposalId: p.proposalId,
            uid: user.uid,
          ),
          builder: (context, voteSnapshot) {
            final userVote = voteSnapshot.data;
            final hasVoted = userVote != null;

            final totalVotes = p.yesVotes + p.noVotes;
            final progress = p.memberCount == 0
                ? 0.0
                : totalVotes / p.memberCount;

            Color statusColor = Colors.blue;
            if (p.status == 'approved') statusColor = Colors.green;
            if (p.status == 'rejected') statusColor = Colors.red;
            final eventDate = p.eventDate?.toDate();

            final formattedDate = eventDate == null
                ? "-"
                : DateFormat("dd/MM/yyyy").format(eventDate);

            final formattedTime = eventDate == null
                ? "-"
                : DateFormat("HH:mm").format(eventDate);
            Future<void> submitVote(String vote) async {
              await ProposalService.instance.vote(
                hubId: p.hubId,
                proposalId: p.proposalId,
                uid: user.uid,
                vote: vote,
              );

              if (!context.mounted) return;

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Vote submitted.')));
            }

            return Scaffold(
              appBar: AppBar(title: const Text('Proposal')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.how_to_vote_rounded,
                        size: 64,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      p.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.description,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    Chip(
                      backgroundColor: statusColor.withOpacity(.15),
                      label: Text(
                        p.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.event, color: Colors.blue),

                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Event",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  Text(
                                    "📅 $formattedDate",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    "🕒 $formattedTime",
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$totalVotes / ${p.memberCount} members voted',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '👍 YES',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('${p.yesVotes}'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '👎 NO',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('${p.noVotes}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (hasVoted)
                      Card(
                        color: userVote == 'yes'
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        child: ListTile(
                          leading: Icon(
                            userVote == 'yes'
                                ? Icons.check_circle
                                : Icons.cancel,
                          ),
                          title: Text(
                            userVote == 'yes'
                                ? 'You voted YES'
                                : 'You voted NO',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: hasVoted || p.status != 'voting'
                            ? null
                            : () => submitVote('yes'),
                        icon: const Icon(Icons.thumb_up),
                        label: const Text('Vote YES'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: hasVoted || p.status != 'voting'
                            ? null
                            : () => submitVote('no'),
                        icon: const Icon(Icons.thumb_down),
                        label: const Text('Vote NO'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
