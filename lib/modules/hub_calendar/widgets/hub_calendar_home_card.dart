import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../screens/hub_calendar_screen.dart';
import '../services/event_service.dart';

class HubCalendarHomeCard extends StatelessWidget {
  final String hubId;
  final String ownerId;

  const HubCalendarHomeCard({
    super.key,
    required this.hubId,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventModel>>(
      stream: EventService.instance.eventsStream(hubId),
      builder: (context, snapshot) {
        final events = snapshot.data ?? [];
        final EventModel? nextEvent =
            events.isNotEmpty ? events.first : null;

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HubCalendarScreen(
                  hubId: hubId,
                  ownerId: ownerId,
                ),
              ),
            );
          },
          child: Card(
            elevation: 3,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Hub Calendar",
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  if (nextEvent == null)
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "No upcoming events",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Tap to open the calendar.",
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nextEvent.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.blue,
                            ),

                            const SizedBox(width: 6),

                            Text(
                              "${nextEvent.eventDate.toDate().day.toString().padLeft(2, '0')}/"
                              "${nextEvent.eventDate.toDate().month.toString().padLeft(2, '0')}/"
                              "${nextEvent.eventDate.toDate().year}",
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(width: 16),

                            const Icon(
                              Icons.schedule,
                              size: 16,
                              color: Colors.blue,
                            ),

                            const SizedBox(width: 6),

                            Text(
                              "${nextEvent.eventDate.toDate().hour.toString().padLeft(2, '0')}:"
                              "${nextEvent.eventDate.toDate().minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Icon(
                        Icons.event_available,
                        size: 18,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${events.length} upcoming event${events.length == 1 ? "" : "s"}",
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}