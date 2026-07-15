import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_model.dart';

class EventRepository {
  EventRepository._();

  static final EventRepository instance = EventRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> eventsCollection(
    String hubId,
  ) {
    return _firestore
        .collection("hubs")
        .doc(hubId)
        .collection("events");
  }

  Future<void> createEvent(
    EventModel event,
  ) async {
    await eventsCollection(event.hubId)
        .doc(event.eventId)
        .set(event.toFirestore());
  }

  Future<void> updateEvent(
    EventModel event,
  ) async {
    await eventsCollection(event.hubId)
        .doc(event.eventId)
        .update(event.toFirestore());
  }

  Future<void> deleteEvent({
    required String hubId,
    required String eventId,
  }) async {
    await eventsCollection(hubId)
        .doc(eventId)
        .delete();
  }

  Future<EventModel?> getEvent({
    required String hubId,
    required String eventId,
  }) async {
    final doc = await eventsCollection(hubId)
        .doc(eventId)
        .get();

    if (!doc.exists) return null;

    return EventModel.fromFirestore(doc.data()!);
  }

  Stream<EventModel?> eventStream({
    required String hubId,
    required String eventId,
  }) {
    return eventsCollection(hubId)
        .doc(eventId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;

      return EventModel.fromFirestore(doc.data()!);
    });
  }

  Stream<List<EventModel>> eventsStream(
    String hubId,
  ) {
    return eventsCollection(hubId)
        .orderBy("eventDate")
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    EventModel.fromFirestore(doc.data()),
              )
              .toList(),
        );
  }
}