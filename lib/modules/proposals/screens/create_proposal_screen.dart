import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/proposal_model.dart';
import '../services/proposal_service.dart';
import '../../../services/user_service.dart';

class CreateProposalScreen extends StatefulWidget {
  final String gubId;
  final int memberCount;

  const CreateProposalScreen({
    super.key,
    required this.gubId,
    required this.memberCount,
  });

  @override
  State<CreateProposalScreen> createState() => _CreateProposalScreenState();
}

class _CreateProposalScreenState extends State<CreateProposalScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? eventDate;
  TimeOfDay? eventTime;

  int votingDays = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Proposal")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.how_to_vote_rounded, size: 70, color: Colors.blue),

          const SizedBox(height: 18),

          const Text(
            "Create a Proposal",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          const Text(
            "Ask your Hub members to vote on an idea.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 30),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: "Proposal title",
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),

                  const SizedBox(height: 18),

                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: "Description",
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(
                    eventDate == null
                        ? "Choose event date"
                        : "${eventDate!.day}/${eventDate!.month}/${eventDate!.year}",
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: DateTime.now(),
                    );

                    if (date != null) {
                      setState(() {
                        eventDate = date;
                      });
                    }
                  },
                ),
                const Divider(height: 1),

                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(
                    eventTime == null
                        ? "Choose event time"
                        : "${eventTime!.hour.toString().padLeft(2, '0')}:${eventTime!.minute.toString().padLeft(2, '0')}",
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );

                    if (time != null) {
                      setState(() {
                        eventTime = time;
                      });
                    }
                  },
                ),
                const Divider(height: 1),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<int>(
                    value: votingDays,
                    decoration: const InputDecoration(
                      labelText: "Voting duration",
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text("1 day")),
                      DropdownMenuItem(value: 3, child: Text("3 days")),
                      DropdownMenuItem(value: 7, child: Text("7 days")),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        votingDays = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 35),

          SizedBox(
            height: 55,
            child: FilledButton.icon(
              icon: const Icon(Icons.how_to_vote),
              label: const Text(
                "Create Proposal",
                style: TextStyle(fontSize: 17),
              ),
              onPressed: () async {
                if (_titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Enter a title.")),
                  );
                  return;
                }

                if (eventDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Choose an event date.")),
                  );
                  return;
                }

                if (eventTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Choose an event time.")),
                  );
                  return;
                }
                final user = FirebaseAuth.instance.currentUser!;
                final creatorName = await UserService().getDisplayName(
                  user.uid,
                );

                debugPrint("CreatorName: $creatorName");

                final proposal = ProposalModel(
                  gubId: widget.gubId,
                  proposalId: FirebaseFirestore.instance
                      .collection("temp")
                      .doc()
                      .id,
                  title: _titleController.text.trim(),
                  description: _descriptionController.text.trim(),
                  creatorId: user.uid,
                  creatorName: creatorName,
                  status: "voting",
                  createdAt: Timestamp.now(),
                  expiresAt: Timestamp.fromDate(
                    DateTime.now().add(Duration(days: votingDays)),
                  ),
                  eventDate: Timestamp.fromDate(
                    DateTime(
                      eventDate!.year,
                      eventDate!.month,
                      eventDate!.day,
                      eventTime!.hour,
                      eventTime!.minute,
                    ),
                  ),
                  type: "custom",
                  yesVotes: 0,
                  noVotes: 0,
                  memberCount: widget.memberCount,
                  resultProcessed: false,
                  eventCreated: false,
                  tasksCreated: false,
                );

                await ProposalService.instance.createProposal(
                  proposal: proposal,
                );

                if (!context.mounted) return;

                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
