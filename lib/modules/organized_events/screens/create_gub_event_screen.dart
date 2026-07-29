import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../widgets/gub_screen_background.dart';
import '../models/gub_event_model.dart';
import '../services/gub_event_service.dart';

class CreateGubEventScreen extends StatefulWidget {
  final String gubId;
  final String sourceType;
  final String? sourceId;
  final String? sourcePreview;
  final String? originUserId;
  final String? sourceAuthorName;

  const CreateGubEventScreen({
    super.key,
    required this.gubId,
    this.sourceType = 'manual',
    this.sourceId,
    this.sourcePreview,
    this.originUserId,
    this.sourceAuthorName,
  });

  bool get isChatConversion =>
      sourceType == 'chat' && sourceId != null && sourcePreview != null;

  @override
  State<CreateGubEventScreen> createState() => _CreateGubEventScreenState();
}

class _CreateGubEventScreenState extends State<CreateGubEventScreen> {
  static const _primaryColor = Color(0xFF2563EB);
  static const _borderColor = Color(0xFFDCE6F5);

  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _selected = <String>{};
  final _tasks = <String, TextEditingController>{};
  List<Map<String, String>>? _members;

  @override
  void initState() {
    super.initState();
    if (widget.isChatConversion) {
      final preview = widget.sourcePreview!;
      _title.text = preview.length <= 80 ? preview : preview.substring(0, 80);
    }
    GubEventService.instance.members(widget.gubId).then((members) {
      if (mounted) setState(() => _members = members);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    for (final controller in _tasks.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final assignments = (_members ?? [])
        .where((member) => _selected.contains(member['userId']))
        .map(
          (member) => GubEventAssignment(
            userId: member['userId']!,
            userName: member['userName']!,
            taskText: _tasks[member['userId']]!.text.trim(),
            isCompleted: false,
          ),
        )
        .toList();

    try {
      await GubEventService.instance.create(
        gubId: widget.gubId,
        title: _title.text,
        description: _description.text,
        location: _location.text,
        assignments: assignments,
        sourceType: widget.isChatConversion ? 'chat' : 'manual',
        sourceId: widget.isChatConversion ? widget.sourceId : null,
        sourcePreview: widget.isChatConversion ? widget.sourcePreview : null,
        originUserId: widget.isChatConversion ? widget.originUserId : null,
        sourceAuthorName: widget.isChatConversion
            ? widget.sourceAuthorName
            : null,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _members;
    return GubScreenBackground(
      variant: GubBackgroundAssignments.events,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('Create event'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        body: members == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                top: false,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Card(
                    margin: EdgeInsets.zero,
                    elevation: 1,
                    shadowColor: const Color(
                      0xFF0F172A,
                    ).withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.isChatConversion) ...[
                            _ChatSourceCard(
                              authorName: widget.sourceAuthorName,
                              message: widget.sourcePreview!,
                            ),
                            const SizedBox(height: 20),
                          ],
                          _EventTextField(
                            controller: _title,
                            label: 'Title',
                            icon: Icons.event_outlined,
                            limit: 80,
                          ),
                          const SizedBox(height: 12),
                          _EventTextField(
                            controller: _description,
                            label: 'Description',
                            icon: Icons.notes_rounded,
                            limit: 500,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          _EventTextField(
                            controller: _location,
                            label: 'Location',
                            icon: Icons.location_on_outlined,
                            limit: 120,
                          ),
                          const SizedBox(height: 22),
                          const _AssignmentHeader(),
                          const SizedBox(height: 12),
                          ...members.map(_buildMemberRow),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.add_task_rounded),
                            label: const Text('Create event'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildMemberRow(Map<String, String> member) {
    final id = member['userId']!;
    final name = member['userName']!;
    final selected = _selected.contains(id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.fromLTRB(4, 2, 12, selected ? 14 : 2),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? const Color(0xFFBFDBFE) : _borderColor,
        ),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: selected,
            secondary: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFDBEAFE),
              child: Text(
                _initial(name),
                style: const TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onChanged: (value) => setState(() {
              if (value == true) {
                _selected.add(id);
              } else {
                _selected.remove(id);
              }
            }),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _EventTextField(
                controller: _tasks.putIfAbsent(id, TextEditingController.new),
                label: 'Task for $name',
                icon: Icons.task_alt_rounded,
                limit: 160,
              ),
            ),
        ],
      ),
    );
  }
}

class _AssignmentHeader extends StatelessWidget {
  const _AssignmentHeader();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Icon(
        Icons.groups_2_outlined,
        color: _CreateGubEventScreenState._primaryColor,
      ),
      SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event assignments',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              'Select members and assign each one a task.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
      ),
    ],
  );
}

class _EventTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int limit;
  final int maxLines;

  const _EventTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.limit,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLength: limit,
    maxLines: maxLines,
    inputFormatters: [LengthLimitingTextInputFormatter(limit)],
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
    ),
  );
}

class _ChatSourceCard extends StatelessWidget {
  final String message;
  final String? authorName;

  const _ChatSourceCard({required this.message, this.authorName});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFBFDBFE)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text(
              'From chat',
              style: TextStyle(
                color: Color(0xFF2563EB),
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
        const SizedBox(height: 6),
        Text(
          '“$message”',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(height: 1.35),
        ),
      ],
    ),
  );
}

String _initial(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
}
