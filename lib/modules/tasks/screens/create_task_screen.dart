import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/models/member_option.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/gub_service.dart';
import '../../../widgets/gub_screen_background.dart';
import '../models/task_model.dart';
import '../repositories/task_repository.dart';
import '../services/task_service.dart';
import '../widgets/create_task_button.dart';
import '../widgets/due_date_tile.dart';
import '../widgets/member_selector.dart';
import '../widgets/task_text_field.dart';

class CreateTaskScreen extends StatefulWidget {
  final String gubId;
  final String sourceType;
  final String? sourceId;
  final String? sourcePreview;
  final String? originUserId;
  final String? sourceAuthorName;

  const CreateTaskScreen({
    super.key,
    required this.gubId,
    this.sourceType = "manual",
    this.sourceId,
    this.sourcePreview,
    this.originUserId,
    this.sourceAuthorName,
  });

  bool get isChatConversion =>
      sourceType == "chat" && sourceId != null && sourcePreview != null;

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _additionalDetailsController =
      TextEditingController();

  bool _loading = false;
  Timestamp? _dueDate;
  MemberOption? _selectedMember;

  @override
  void dispose() {
    _textController.dispose();
    _additionalDetailsController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (picked == null || !mounted) return;

    setState(() => _dueDate = Timestamp.fromDate(picked));
  }

  Future<void> _createTask() async {
    if (_loading) return;

    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter a task.")));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      final userData = await UserRepository.instance.getUser(user.uid);
      final creatorName = userData?["displayName"] ?? "User";
      final taskId = TaskRepository.instance.generateTaskId();
      final additionalDetails = _additionalDetailsController.text.trim();

      final task = TaskModel(
        gubId: widget.gubId,
        taskId: taskId,
        title: _textController.text.trim(),
        description: "",
        creatorId: user.uid,
        creatorName: creatorName,
        assignedUserId: _selectedMember?.userId,
        assignedUserName: _selectedMember?.userName,
        sourceType: widget.sourceType,
        sourceId: widget.sourceId,
        sourcePreview: widget.sourcePreview,
        originUserId: widget.originUserId,
        sourceAuthorName: widget.sourceAuthorName,
        additionalDetails:
            widget.isChatConversion && additionalDetails.isNotEmpty
            ? additionalDetails
            : null,
        status: "active",
        priority: "normal",
        createdAt: Timestamp.now(),
        dueDate: _dueDate,
        completedAt: null,
        completedBy: null,
        notificationsEnabled: true,
        archived: false,
      );

      await TaskService.instance.createTask(task);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.tasks,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Create Task"),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: FutureBuilder<List<MemberOption>>(
          future: GubService().getMembers(widget.gubId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final members = snapshot.data ?? [];
            if (_selectedMember == null && members.isNotEmpty) {
              _selectedMember = members.first;
            }

            if (widget.isChatConversion) {
              return ListView(
                padding: const EdgeInsets.all(20),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _ChatSourceCard(
                    message: widget.sourcePreview!,
                    authorName: widget.sourceAuthorName,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _additionalDetailsController,
                    minLines: 3,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: "Additional details (optional)",
                      hintText: "Explain what needs to be done",
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._buildTaskFields(members),
                  const SizedBox(height: 32),
                  CreateTaskButton(loading: _loading, onPressed: _createTask),
                ],
              );
            }

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ..._buildTaskFields(members),
                  const Spacer(),
                  CreateTaskButton(loading: _loading, onPressed: _createTask),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildTaskFields(List<MemberOption> members) {
    return [
      TaskTextField(controller: _textController),
      const SizedBox(height: 20),
      MemberSelector(
        members: members,
        selectedUserId: _selectedMember?.userId,
        onChanged: (member) {
          setState(() => _selectedMember = member);
        },
      ),
      const SizedBox(height: 20),
      DueDateTile(dueDate: _dueDate, onTap: _pickDueDate),
    ];
  }
}

class _ChatSourceCard extends StatelessWidget {
  final String message;
  final String? authorName;

  const _ChatSourceCard({required this.message, this.authorName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2563EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text(
                "Created from chat",
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (authorName != null && authorName!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              authorName!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF2563EB),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            "“$message”",
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}
