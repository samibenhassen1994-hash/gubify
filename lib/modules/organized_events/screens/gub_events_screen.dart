import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../../chat/widgets/gub_chat_overlay.dart';
import '../models/gub_event_model.dart';
import '../services/gub_event_service.dart';

class GubEventsScreen extends StatelessWidget {
  final String gubId;
  const GubEventsScreen({super.key, required this.gubId});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Events')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => GubChatOverlay.runWithChatOverlayHidden(
        () => Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => CreateGubEventScreen(gubId: gubId)),
        ),
      ),
      icon: const Icon(Icons.add),
      label: const Text('Create event'),
    ),
    body: StreamBuilder<List<GubEventModel>>(
      stream: GubEventService.instance.stream(gubId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final events = [...snapshot.data!]
          ..sort(
            (a, b) =>
                (a.status == 'completed' ? 1 : 0) -
                (b.status == 'completed' ? 1 : 0),
          );
        if (events.isEmpty) return const Center(child: Text('No events yet.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (_, index) {
            final event = events[index];
            return Card(
              child: ListTile(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GubEventDetailsScreen(
                      gubId: gubId,
                      eventId: event.eventId,
                    ),
                  ),
                ),
                title: Text(event.title),
                subtitle: Text(
                  '${event.completedCount} / ${event.assignments.length} completed',
                ),
                trailing: Chip(
                  label: Text(
                    event.status == 'completed' ? 'Completed' : 'Active',
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class CreateGubEventScreen extends StatefulWidget {
  final String gubId;
  const CreateGubEventScreen({super.key, required this.gubId});
  @override
  State<CreateGubEventScreen> createState() => _CreateGubEventScreenState();
}

class _CreateGubEventScreenState extends State<CreateGubEventScreen> {
  final _title = TextEditingController(),
      _description = TextEditingController(),
      _location = TextEditingController();
  List<Map<String, String>>? _members;
  final _selected = <String>{};
  final _tasks = <String, TextEditingController>{};
  @override
  void initState() {
    super.initState();
    GubEventService.instance.members(widget.gubId).then((v) {
      if (mounted) setState(() => _members = v);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    for (final c in _tasks.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final assignments = (_members ?? [])
        .where((m) => _selected.contains(m['userId']))
        .map(
          (m) => GubEventAssignment(
            userId: m['userId']!,
            userName: m['userName']!,
            taskText: _tasks[m['userId']]!.text.trim(),
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
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _members;
    return GubScreenBackground(
      variant: GubBackgroundAssignments.tasks,
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Card(
                    elevation: 1,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(20),
                      children: [
                        TextField(
                          controller: _title,
                          decoration: const InputDecoration(labelText: 'Title'),
                        ),
                        TextField(
                          controller: _description,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                          ),
                        ),
                        TextField(
                          controller: _location,
                          decoration: const InputDecoration(
                            labelText: 'Location',
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...members.map((m) {
                          final id = m['userId']!;
                          return Column(
                            children: [
                              CheckboxListTile(
                                value: _selected.contains(id),
                                title: Text(m['userName']!),
                                onChanged: (v) => setState(() {
                                  if (v == true) {
                                    _selected.add(id);
                                  } else {
                                    _selected.remove(id);
                                  }
                                }),
                              ),
                              if (_selected.contains(id))
                                TextField(
                                  controller: _tasks.putIfAbsent(
                                    id,
                                    TextEditingController.new,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Task for ${m['userName']}',
                                  ),
                                ),
                            ],
                          );
                        }),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _save,
                          child: const Text('Create event'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class GubEventDetailsScreen extends StatelessWidget {
  final String gubId, eventId;
  const GubEventDetailsScreen({
    super.key,
    required this.gubId,
    required this.eventId,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Event')),
    body: StreamBuilder<GubEventModel?>(
      stream: GubEventService.instance.eventStream(gubId, eventId),
      builder: (context, snapshot) {
        final event = snapshot.data;
        if (event == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final uid = FirebaseAuth.instance.currentUser?.uid;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(event.title, style: Theme.of(context).textTheme.headlineSmall),
            if (event.description != null) Text(event.description!),
            if (event.location != null) Text(event.location!),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: event.assignments.isEmpty
                  ? 0
                  : event.completedCount / event.assignments.length,
            ),
            Text(
              '${event.completedCount} of ${event.assignments.length} tasks completed',
            ),
            ...event.assignments.map(
              (a) => Card(
                child: ListTile(
                  title: Text(a.userName),
                  subtitle: Text(a.taskText),
                  trailing: a.isCompleted
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : a.userId == uid && event.status == 'active'
                      ? FilledButton(
                          onPressed: () => GubEventService.instance
                              .setOwnCompletion(event: event, completed: true),
                          child: const Text("I've done my task"),
                        )
                      : null,
                ),
              ),
            ),
            if (event.status == 'active')
              ...event.assignments
                  .where((a) => a.userId == uid && a.isCompleted)
                  .map(
                    (_) => OutlinedButton(
                      onPressed: () => GubEventService.instance
                          .setOwnCompletion(event: event, completed: false),
                      child: const Text('Undo completion'),
                    ),
                  ),
          ],
        );
      },
    ),
  );
}
