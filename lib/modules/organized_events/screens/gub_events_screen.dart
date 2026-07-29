import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../../chat/widgets/gub_chat_overlay.dart';
import '../models/gub_event_model.dart';
import '../services/gub_event_service.dart';
import 'create_gub_event_screen.dart';
import 'gub_event_details_screen.dart';

class GubEventsScreen extends StatelessWidget {
  static const double _createButtonClearance = kFloatingActionButtonMargin + 56;

  final String gubId;

  const GubEventsScreen({super.key, required this.gubId});

  @override
  Widget build(BuildContext context) => ChatFloatingActionButtonRouteScope(
    additionalBottomOffset: _createButtonClearance,
    child: GubScreenBackground(
      variant: GubBackgroundAssignments.events,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Events'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => GubChatOverlay.runWithChatOverlayHidden(
            () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => CreateGubEventScreen(gubId: gubId),
              ),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Create event'),
        ),
        body: StreamBuilder<List<GubEventModel>>(
          stream: GubEventService.instance.stream(gubId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Unable to load events.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final events = [...snapshot.data!]
              ..sort(
                (a, b) =>
                    (a.status == 'completed' ? 1 : 0) -
                    (b.status == 'completed' ? 1 : 0),
              );
            if (events.isEmpty) {
              return const Center(child: Text('No events yet.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final percentage = event.assignments.isEmpty
                    ? 0
                    : (event.completedCount / event.assignments.length * 100)
                          .round();
                return Card(
                  child: ListTile(
                    onTap: () => Navigator.push<void>(
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
                      '${event.completedCount} / ${event.assignments.length} completed · $percentage%',
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
      ),
    ),
  );
}
