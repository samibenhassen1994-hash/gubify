import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../chat/widgets/deleted_user_identity_builder.dart';
import 'package:intl/intl.dart';
import '../../../core/models/creation_availability.dart';
import '../../../core/models/deletion_context.dart';
import '../../../core/navigation/creation_gate.dart';
import '../../../widgets/gub_content_card.dart';
import '../../../widgets/gub_screen_background.dart';
import '../../../widgets/delete_item_dialog.dart';
import '../../chat/widgets/gub_chat_overlay.dart';
import '../models/proposal_model.dart';
import 'create_proposal_screen.dart';
import '../services/proposal_service.dart';

class ProposalDetailsScreen extends StatefulWidget {
  final ProposalModel proposal;

  const ProposalDetailsScreen({super.key, required this.proposal});

  @override
  State<ProposalDetailsScreen> createState() => _ProposalDetailsScreenState();
}

class _ProposalDetailsScreenState extends State<ProposalDetailsScreen> {
  bool _openingOriginalMessage = false;
  late final Future<DeletionContext> _deletionContextFuture;

  @override
  void initState() {
    super.initState();
    _deletionContextFuture = ProposalService.instance.deletionContext(
      gubId: widget.proposal.gubId,
      proposalId: widget.proposal.proposalId,
    );
  }

  Future<void> _deleteProposal() async {
    final deletionContext = await _deletionContextFuture;
    if (!mounted || !deletionContext.canDelete) return;
    final deleted = await showDeleteItemDialog(
      context: context,
      title: 'Delete proposal?',
      moduleName: 'proposal',
      deletionContext: deletionContext,
      successMessage: 'Proposal deleted.',
      onDelete: () => ProposalService.instance.deleteProposal(
        gubId: widget.proposal.gubId,
        proposalId: widget.proposal.proposalId,
      ),
    );
    if (deleted && mounted) Navigator.pop(context);
  }

  Future<void> _openOriginalMessage(ProposalModel proposal) async {
    final messageId = proposal.sourceId;
    if (_openingOriginalMessage || messageId == null || messageId.isEmpty) {
      return;
    }

    setState(() => _openingOriginalMessage = true);
    final opened = await GubChatOverlay.openChat(
      gubId: proposal.gubId,
      initialMessageId: messageId,
    );

    if (!mounted) return;
    setState(() => _openingOriginalMessage = false);

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to open the original message.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return GubScreenBackground(
      variant: GubBackgroundAssignments.proposals,
      child: StreamBuilder<ProposalModel?>(
        stream: ProposalService.instance.proposalStream(
          gubId: widget.proposal.gubId,
          proposalId: widget.proposal.proposalId,
        ),
        builder: (context, proposalSnapshot) {
          if (proposalSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (proposalSnapshot.hasError) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: _proposalAppBar(),
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
              backgroundColor: Colors.transparent,
              appBar: _proposalAppBar(),
              body: const Center(
                child: Text('Proposal not found or has been deleted.'),
              ),
            );
          }

          return StreamBuilder<String?>(
            stream: ProposalService.instance.userVoteStream(
              gubId: p.gubId,
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
                  gubId: p.gubId,
                  proposalId: p.proposalId,
                  uid: user.uid,
                  vote: vote,
                );

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vote submitted.')),
                );
              }

              return Scaffold(
                backgroundColor: Colors.transparent,
                appBar: _proposalAppBar(),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GubContentCard(
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
                            if (p.sourceType == "chat" &&
                                p.sourcePreview?.isNotEmpty == true) ...[
                              const SizedBox(height: 20),
                              DeletedUserIdentityBuilder(
                                userId: p.originUserId ?? '',
                                currentDisplayName:
                                    p.sourceAuthorName ?? 'User',
                                resolveCurrentDisplayName:
                                    p.originUserId?.trim().isNotEmpty == true,
                                builder: (context, displayName, deleted) =>
                                    _ProposalChatSourceCard(
                                      message: p.sourcePreview!,
                                      authorName: displayName,
                                      opening: _openingOriginalMessage,
                                      onTap: p.sourceId?.isNotEmpty == true
                                          ? () => _openOriginalMessage(p)
                                          : null,
                                    ),
                              ),
                            ],
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
                              backgroundColor: statusColor.withValues(
                                alpha: .15,
                              ),
                              label: Text(
                                p.status.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
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
                      GubContentCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          '👍 YES',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text('${p.yesVotes}'),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          '👎 NO',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
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
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final allowed =
                                      await CreationGate.ensureAvailable(
                                        context: context,
                                        gubId: p.gubId,
                                        moduleType: CreationModuleType.proposal,
                                      );
                                  if (!allowed || !context.mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CreateProposalScreen(
                                        gubId: p.gubId,
                                        memberCount: p.memberCount,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Create Proposal'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  PreferredSizeWidget _proposalAppBar() {
    return AppBar(
      title: const Text("Proposal"),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [
        FutureBuilder<DeletionContext>(
          future: _deletionContextFuture,
          builder: (context, snapshot) => snapshot.data?.canDelete == true
              ? IconButton(
                  tooltip: 'Delete proposal',
                  onPressed: _deleteProposal,
                  icon: const Icon(Icons.delete_outline_rounded),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ProposalChatSourceCard extends StatelessWidget {
  final String message;
  final String? authorName;
  final bool opening;
  final VoidCallback? onTap;

  const _ProposalChatSourceCard({
    required this.message,
    required this.opening,
    this.authorName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GubContentCard(
      child: InkWell(
        onTap: opening ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    "From chat",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (authorName?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  authorName!.trim(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 8),
              Text('“$message”'),
              if (onTap != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    opening ? "Opening chat..." : "View original message",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
