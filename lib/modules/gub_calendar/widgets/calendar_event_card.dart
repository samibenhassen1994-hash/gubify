import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_model.dart';

class CalendarEventCard extends StatelessWidget {
  final EventModel event;

  /// Widget opzionale mostrato in alto a destra
  final Widget? trailing;

  const CalendarEventCard({super.key, required this.event, this.trailing});

  @override
  Widget build(BuildContext context) {
    final date = event.eventDate.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue.withValues(alpha: .12),
              child: const Icon(Icons.event, color: Colors.blue),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      if (trailing != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: trailing!,
                        ),
                    ],
                  ),

                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 6),

                    Text(
                      event.description,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 18, color: Colors.blue),

                      const SizedBox(width: 6),

                      Text(
                        DateFormat("HH:mm").format(date),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      backgroundColor: Colors.blue.withValues(alpha: .10),
                      label: Text(
                        event.status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
