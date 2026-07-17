import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/models/member_option.dart';

import '../../../repositories/user_repository.dart';

import '../../../services/gub_service.dart';

import '../models/task_model.dart';
import '../repositories/task_repository.dart';
import '../services/task_service.dart';

import '../widgets/create_task_button.dart';
import '../widgets/due_date_tile.dart';
import '../widgets/member_selector.dart';
import '../widgets/task_text_field.dart';

class CreateTaskScreen extends StatefulWidget {
  final String hubId;

  const CreateTaskScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<CreateTaskScreen> createState() =>
      _CreateTaskScreenState();
}

class _CreateTaskScreenState
    extends State<CreateTaskScreen> {

  final TextEditingController _textController =
      TextEditingController();

  bool _loading = false;

  Timestamp? _dueDate;

  MemberOption? _selectedMember;

  @override
  void dispose() {
    _textController.dispose();
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

    if (picked == null) {
      return;
    }

    setState(() {
      _dueDate = Timestamp.fromDate(picked);
    });
  }

  Future<void> _createTask() async {

    if (_textController.text.trim().isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please enter a task.",
          ),
        ),
      );

      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {

      final userData =
          await UserRepository.instance.getUser(user.uid);

      final creatorName =
          userData?["displayName"] ?? "User";

      final taskId =
          TaskRepository.instance.generateTaskId();
                final task = TaskModel(
        hubId: widget.hubId,
        taskId: taskId,

        title: _textController.text.trim(),
        description: "",

        creatorId: user.uid,
        creatorName: creatorName,

        assignedUserId: _selectedMember?.userId,
        assignedUserName: _selectedMember?.userName,

        sourceType: "manual",
        sourceId: null,
        sourcePreview: null,
        originUserId: null,

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

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
        ),
      );

    } finally {

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }

    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Task"),
      ),
      body: FutureBuilder<List<MemberOption>>(
        future: GubService().getMembers(widget.hubId),
        builder: (context, snapshot) {

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final members = snapshot.data ?? [];

          if (_selectedMember == null &&
              members.isNotEmpty) {
            _selectedMember = members.first;
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [

                TaskTextField(
                  controller: _textController,
                ),

                const SizedBox(height: 20),

                MemberSelector(
                  members: members,
                  selectedUserId:
                      _selectedMember?.userId,
                  onChanged: (member) {
                    setState(() {
                      _selectedMember = member;
                    });
                  },
                ),

                const SizedBox(height: 20),

                DueDateTile(
                  dueDate: _dueDate,
                  onTap: _pickDueDate,
                ),

                const Spacer(),

                CreateTaskButton(
                  loading: _loading,
                  onPressed: _createTask,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}