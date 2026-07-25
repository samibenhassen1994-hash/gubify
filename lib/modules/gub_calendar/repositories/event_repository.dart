import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_model.dart';

class EventRepository {
  EventRepository._();

  static final EventRepository instance = EventRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> eventsCollection(String gubId) {
    return _firestore.collection("gubs").doc(gubId).collection("events");
  }

  Future<void> createEvent(EventModel event) async {
    await eventsCollection(
      event.gubId,
    ).doc(event.eventId).set(event.toFirestore());
  }

  Future<void> updateEvent(EventModel event) async {
    await eventsCollection(
      event.gubId,
    ).doc(event.eventId).update(event.toFirestore());
  }

  Future<void> deleteEvent({
    required String gubId,
    required String eventId,
  }) async {
    await eventsCollection(gubId).doc(eventId).delete();
  }

  Future<EventModel?> getEvent({
    required String gubId,
    required String eventId,
  }) async {
    final doc = await eventsCollection(gubId).doc(eventId).get();

    if (!doc.exists) return null;

    return EventModel.fromFirestore(doc.data()!);
  }

  Stream<EventModel?> eventStream({
    required String gubId,
    required String eventId,
  }) {
    return eventsCollection(gubId).doc(eventId).snapshots().map((doc) {
      if (!doc.exists) return null;

      return EventModel.fromFirestore(doc.data()!);
    });
  }

  Stream<List<EventModel>> eventsStream(String gubId) {
    return eventsCollection(gubId)
        .orderBy("eventDate")
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EventModel.fromFirestore(doc.data()))
              .toList(),
        );
  }

  Stream<List<EventModel>> profileActivityCandidatesStream(String gubId) {
    return eventsCollection(gubId).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc.data()))
          .toList(growable: false),
    );
  }
}
