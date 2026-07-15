import 'package:cloud_firestore/cloud_firestore.dart';

import '../../proposals/models/proposal_model.dart';
import '../models/event_model.dart';
import '../repositories/event_repository.dart';
import '../../proposals/repositories/proposal_repository.dart';

class EventService {
  EventService._();

  static final EventService instance = EventService._();

  Stream<List<EventModel>> eventsStream(
    String hubId,
  ) {
    return EventRepository.instance.eventsStream(hubId);
  }

  Stream<EventModel?> eventStream({
    required String hubId,
    required String eventId,
  }) {
    return EventRepository.instance.eventStream(
      hubId: hubId,
      eventId: eventId,
    );
  }

  Future<void> createEvent(
    EventModel event,
  ) async {
    await EventRepository.instance.createEvent(event);
  }

  Future<void> createFromProposal(
    ProposalModel proposal,
  ) async {
    // Evita di creare due eventi per la stessa proposal
    if (proposal.eventCreated) return;

    // Se non è presente una data evento, non creare nulla
    if (proposal.eventDate == null) return;

    final eventId = FirebaseFirestore.instance
        .collection("temp")
        .doc()
        .id;

    final event = EventModel(
      hubId: proposal.hubId,
      eventId: eventId,
      proposalId: proposal.proposalId,
      title: proposal.title,
      description: proposal.description,
      type: proposal.type,
      creatorId: proposal.creatorId,
      creatorName: proposal.creatorName,
      eventDate: proposal.eventDate!,
      createdAt: Timestamp.now(),
      status: "scheduled",
    );

    await EventRepository.instance.createEvent(event);

await ProposalRepository.instance.updateProposal(
  proposal.copyWith(
    eventCreated: true,
  ),
);
  
  }

  Future<void> updateEvent(
    EventModel event,
  ) async {
    await EventRepository.instance.updateEvent(event);
  }

  Future<void> deleteEvent({
    required String hubId,
    required String eventId,
  }) async {
    await EventRepository.instance.deleteEvent(
      hubId: hubId,
      eventId: eventId,
    );
  }
}