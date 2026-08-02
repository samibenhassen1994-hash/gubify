import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../repositories/gub_repository.dart';
import '../../proposals/models/proposal_model.dart';
import '../../proposals/repositories/proposal_repository.dart';
import '../models/event_model.dart';
import '../repositories/event_repository.dart';

class EventService {
  EventService._();

  static final EventService instance = EventService._();

  Stream<List<EventModel>> eventsStream(String gubId) =>
      EventRepository.instance.eventsStream(gubId);

  Stream<EventModel?> eventStream({
    required String gubId,
    required String eventId,
  }) => EventRepository.instance.eventStream(gubId: gubId, eventId: eventId);

  Future<void> createEvent(EventModel event) async {
    await _ensureGubActive(event.gubId);
    await EventRepository.instance.createEvent(event);
  }

  Future<void> createFromProposal(ProposalModel proposal) async {
    if (proposal.eventCreated || proposal.eventDate == null) return;
    await _ensureGubActive(proposal.gubId);
    final eventId = FirebaseFirestore.instance.collection('temp').doc().id;
    final event = EventModel(
      gubId: proposal.gubId,
      eventId: eventId,
      proposalId: proposal.proposalId,
      title: proposal.title,
      description: proposal.description,
      type: proposal.type,
      creatorId: proposal.creatorId,
      creatorName: proposal.creatorName,
      eventDate: proposal.eventDate!,
      createdAt: Timestamp.now(),
      status: 'scheduled',
    );
    await EventRepository.instance.createEvent(event);
    await ProposalRepository.instance.updateProposal(
      proposal.copyWith(eventCreated: true),
    );
  }

  Future<void> updateEvent(EventModel event) async {
    await _ensureGubActive(event.gubId);
    await EventRepository.instance.updateEvent(event);
  }

  Future<void> deleteEvent({
    required String gubId,
    required String eventId,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw StateError('You must be signed in to delete this event.');
    }
    await _ensureGubActive(gubId);
    final event = await EventRepository.instance.getEvent(
      gubId: gubId,
      eventId: eventId,
    );
    if (event == null) return;
    final isOwner = await GubRepository.instance.isAuthoritativeOwner(
      gubId: gubId,
      userId: userId,
    );
    if (!isOwner && event.creatorId != userId) {
      throw StateError("You don't have permission to delete this event.");
    }
    await EventRepository.instance.deleteEvent(gubId: gubId, eventId: eventId);
  }

  Future<void> _ensureGubActive(String gubId) async {
    final gub = await GubRepository.instance.getHubAuthoritatively(gubId);
    if (gub == null || gub['deletionStatus'] == 'deleting') {
      throw StateError('This Gub is no longer available.');
    }
  }
}
