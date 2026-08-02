import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/active_creation_limit_exception.dart';
import '../../../core/models/creation_availability.dart';
import '../../../core/models/deletion_context.dart';
import '../../../repositories/creation_cooldown_repository.dart';
import '../../../repositories/gub_repository.dart';
import '../../notifications/services/notification_service.dart';
import '../models/gub_event_model.dart';
import '../repositories/gub_event_repository.dart';

class GubEventService {
  GubEventService._();
  static final instance = GubEventService._();
  final _db = FirebaseFirestore.instance;
  final Set<String> _creationsInProgress = {};

  Future<CreationAvailability> creationAvailability({
    required String gubId,
    String? creatorId,
  }) async {
    final effectiveCreatorId =
        creatorId ?? FirebaseAuth.instance.currentUser?.uid;
    if (effectiveCreatorId == null) {
      throw StateError('You must be signed in to create an event.');
    }
    if (await GubRepository.instance.isAuthoritativeOwner(
      gubId: gubId,
      userId: effectiveCreatorId,
    )) {
      return const CreationAvailability(isUnlimited: true);
    }

    final activeFuture = GubEventRepository.instance.getActiveEventCreatedBy(
      gubId: gubId,
      creatorId: effectiveCreatorId,
    );
    final cooldownFuture = CreationCooldownRepository.instance.get(
      gubId: gubId,
      creatorId: effectiveCreatorId,
      moduleType: CreationModuleType.organizedEvent,
    );
    final results = await Future.wait<Object?>([activeFuture, cooldownFuture]);
    final activeEvent = results[0] as GubEventModel?;
    final cooldown = results[1] as CreationCooldown?;
    return CreationAvailability(
      activeItemId: activeEvent?.eventId,
      activeItemTitle: activeEvent?.title,
      activeItem: activeEvent,
      cooldown: cooldown,
    );
  }

  Stream<List<GubEventModel>> stream(String gubId) =>
      GubEventRepository.instance.stream(gubId);
  Stream<int> activeCountStream(String gubId) => stream(
    gubId,
  ).map((events) => events.where((event) => event.status == 'active').length);
  Stream<GubEventModel?> eventStream(String gubId, String id) =>
      GubEventRepository.instance.eventStream(gubId, id);
  Future<List<Map<String, String>>> members(String gubId) async {
    final s = await _db
        .collection('gubs')
        .doc(gubId)
        .collection('members')
        .get();
    return s.docs.map((d) {
      final v = d.data();
      return {
        'userId': v['uid'] as String? ?? d.id,
        'userName': v['displayName'] as String? ?? 'User',
      };
    }).toList();
  }

  Future<void> create({
    required String gubId,
    required String title,
    required String description,
    required String location,
    DateTime? scheduledAt,
    required List<GubEventAssignment> assignments,
    String sourceType = 'manual',
    String? sourceId,
    String? sourcePreview,
    String? originUserId,
    String? sourceAuthorName,
  }) async {
    await GubRepository.instance.ensureActive(gubId);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in required.');
    }
    if (title.trim().isEmpty ||
        assignments.isEmpty ||
        assignments.any((a) => a.taskText.trim().isEmpty)) {
      throw StateError('Add a title and a task for every selected member.');
    }
    final doc = _db
        .collection('gubs')
        .doc(gubId)
        .collection('organizedEvents')
        .doc();
    final event = GubEventModel(
      eventId: doc.id,
      gubId: gubId,
      title: title.trim(),
      description: description.trim().isEmpty ? null : description.trim(),
      location: location.trim().isEmpty ? null : location.trim(),
      scheduledAt: scheduledAt == null ? null : Timestamp.fromDate(scheduledAt),
      createdBy: user.uid,
      createdByName: user.displayName,
      createdAt: Timestamp.now(),
      status: 'active',
      assignments: assignments,
      sourceType: sourceType,
      sourceId: sourceId,
      sourcePreview: sourcePreview,
      originUserId: originUserId,
      sourceAuthorName: sourceAuthorName,
    );
    final creationKey = '$gubId/${user.uid}';
    if (!_creationsInProgress.add(creationKey)) {
      throw StateError('An event creation is already in progress.');
    }

    try {
      final availability = await creationAvailability(
        gubId: gubId,
        creatorId: user.uid,
      );
      if (availability.hasActiveItem) {
        throw const ActiveCreationLimitException(
          'You already have an active event. Complete it before creating another one.',
        );
      }
      if (availability.isCoolingDown) {
        throw CreationCooldownException(
          'You can create another event in '
          '${formatCooldownRemaining(availability.cooldown!.remaining)}.',
        );
      }

      await GubEventRepository.instance.create(event);
      final recipientIds = assignments
          .map((assignment) => assignment.userId)
          .where((userId) => userId.isNotEmpty && userId != user.uid)
          .toSet()
          .toList(growable: false);
      if (recipientIds.isEmpty) return;

      await NotificationService.instance.send(
        gubId: gubId,
        title: 'New event',
        body:
            '${event.createdByName ?? 'A member'} assigned you a task for ${event.title}.',
        type: 'organized_event_created',
        senderId: user.uid,
        senderName: event.createdByName ?? 'User',
        data: {
          'module': 'organized_events',
          'eventId': event.eventId,
          'organizedEventId': event.eventId,
          'recipientIds': recipientIds,
        },
      );
    } finally {
      _creationsInProgress.remove(creationKey);
    }
  }

  Future<void> setOwnCompletion({
    required GubEventModel event,
    required bool completed,
  }) async {
    await GubRepository.instance.ensureActive(event.gubId);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in required.');
    }
    final becameCompleted = await GubEventRepository.instance.setOwnCompletion(
      gubId: event.gubId,
      eventId: event.eventId,
      userId: user.uid,
      senderName: user.displayName ?? 'User',
      completed: completed,
    );
    if (!becameCompleted) return;
  }

  Future<void> delete({required String gubId, required String eventId}) async {
    await GubRepository.instance.ensureActive(gubId);
    if (!await canDelete(gubId: gubId, eventId: eventId)) {
      throw StateError("You don't have permission to delete this event.");
    }
    await GubEventRepository.instance.delete(gubId: gubId, eventId: eventId);
  }

  Future<bool> canDelete({required String gubId, required String eventId}) {
    return GubEventRepository.instance.canDelete(
      gubId: gubId,
      eventId: eventId,
    );
  }

  Future<DeletionContext> deletionContext({
    required String gubId,
    required String eventId,
  }) {
    return GubEventRepository.instance.deletionContext(
      gubId: gubId,
      eventId: eventId,
    );
  }
}
