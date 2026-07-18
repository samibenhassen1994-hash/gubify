import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event_model.dart';
import '../services/event_service.dart';
import '../widgets/calendar_day_header.dart';
import '../widgets/calendar_event_card.dart';

class GubCalendarScreen extends StatelessWidget {
  final String hubId;
  final String ownerId;

  const GubCalendarScreen({
    super.key,
    required this.hubId,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text("Hub Calendar")),
      body: StreamBuilder<List<EventModel>>(
        stream: EventService.instance.eventsStream(hubId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final events = snapshot.data ?? [];

          if (events.isEmpty) {
            return const Center(
              child: Text("No events yet.", style: TextStyle(fontSize: 16)),
            );
          }

          final groupedEvents = <String, List<EventModel>>{};

          for (final event in events) {
            final date = event.eventDate.toDate();

            final key = "${date.year}-${date.month}-${date.day}";

            groupedEvents.putIfAbsent(key, () => []);

            groupedEvents[key]!.add(event);
          }

          final keys = groupedEvents.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final key = keys[index];

              final dayEvents = groupedEvents[key]!;

              final date = dayEvents.first.eventDate.toDate();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CalendarDayHeader(date: date),

                  ...dayEvents.map((event) {
                    final isOwner = currentUser.uid == ownerId;
                    return CalendarEventCard(
                      event: event,
                      trailing: isOwner
                          ? PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) async {
                                if (value != "delete") return;
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text("Delete Event"),
                                    content: const Text(
                                      "Are you sure you want to delete this event?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text("Cancel"),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text("Delete"),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;
                                await EventService.instance.deleteEvent(
                                  hubId: hubId,
                                  eventId: event.eventId,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Event deleted successfully.",
                                    ),
                                  ),
                                );
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: "delete",
                                  child: Text("Delete Event"),
                                ),
                              ],
                            )
                          : null,
                    );
                  }).toList(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
