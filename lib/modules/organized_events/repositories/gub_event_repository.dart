import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/creation_availability.dart';
import '../../../core/models/deletion_context.dart';
import '../../../repositories/creation_cooldown_repository.dart';
import '../../notifications/models/notification_model.dart';
import '../models/gub_event_model.dart';

class GubEventRepository {
  GubEventRepository._();
  static final instance = GubEventRepository._();
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  CollectionReference<Map<String, dynamic>> _events(String gubId) =>
      _db.collection('gubs').doc(gubId).collection('organizedEvents');
  Stream<List<GubEventModel>> stream(String gubId) => _events(gubId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => GubEventModel.fromFirestore(d.data())).toList(),
      );
  Stream<GubEventModel?> eventStream(String gubId, String id) => _events(gubId)
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? GubEventModel.fromFirestore(d.data()!) : null);
  Future<GubEventModel?> get(String gubId, String id) async {
    final document = await _events(gubId).doc(id).get();
    return document.exists
        ? GubEventModel.fromFirestore(document.data()!)
        : null;
  }

  Future<bool> hasActiveEventCreatedBy({
    required String gubId,
    required String creatorId,
  }) async =>
      await getActiveEventCreatedBy(gubId: gubId, creatorId: creatorId) != null;

  Future<GubEventModel?> getActiveEventCreatedBy({
    required String gubId,
    required String creatorId,
  }) async {
    final snapshot = await _events(gubId)
        .where('createdBy', isEqualTo: creatorId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final document = snapshot.docs.first;
    return GubEventModel.fromFirestore({
      ...document.data(),
      'eventId': document.data()['eventId'] ?? document.id,
      'gubId': document.data()['gubId'] ?? gubId,
    });
  }

  Future<void> create(GubEventModel event) =>
      _events(event.gubId).doc(event.eventId).set(event.toFirestore());

  Future<void> delete({required String gubId, required String eventId}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to delete an event.');
    }

    final eventReference = _events(gubId).doc(eventId);
    final gubReference = _db.collection('gubs').doc(gubId);
    final availableAt = Timestamp.fromDate(
      DateTime.now().add(CreationCooldownRepository.cooldownDuration),
    );

    await _db.runTransaction((transaction) async {
      final eventSnapshot = await transaction.get(eventReference);
      final gubSnapshot = await transaction.get(gubReference);
      if (!eventSnapshot.exists) throw StateError('Event not found.');
      if (!gubSnapshot.exists) throw StateError('Gub not found.');

      final creatorId = eventSnapshot.data()?['createdBy'] as String? ?? '';
      final gubOwnerId = gubSnapshot.data()?['ownerId'] as String? ?? '';
      if (user.uid != creatorId && user.uid != gubOwnerId) {
        throw StateError("You don't have permission to delete this event.");
      }

      transaction.delete(eventReference);
      if (creatorId.isNotEmpty && creatorId != gubOwnerId) {
        CreationCooldownRepository.instance.setInTransaction(
          transaction: transaction,
          gubId: gubId,
          creatorId: creatorId,
          moduleType: CreationModuleType.organizedEvent,
          deletedItemId: eventId,
          deletedBy: user.uid,
          availableAt: availableAt,
        );
      }
    });
  }

  Future<bool> canDelete({
    required String gubId,
    required String eventId,
  }) async {
    return (await deletionContext(gubId: gubId, eventId: eventId)).canDelete;
  }

  Future<DeletionContext> deletionContext({
    required String gubId,
    required String eventId,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const DeletionContext(
        canDelete: false,
        currentUserIsOwner: false,
        creatorId: null,
        ownerId: '',
      );
    }

    final documents = await Future.wait([
      _events(gubId).doc(eventId).get(),
      _db.collection('gubs').doc(gubId).get(),
    ]);
    final event = documents[0];
    final gub = documents[1];
    final creatorId = _nonEmptyString(event.data()?['createdBy']);
    final ownerId = _nonEmptyString(gub.data()?['ownerId']) ?? '';
    return DeletionContext(
      canDelete:
          event.exists &&
          gub.exists &&
          (userId == creatorId || userId == ownerId),
      currentUserIsOwner: userId == ownerId,
      creatorId: creatorId,
      ownerId: ownerId,
    );
  }

  Future<bool> setOwnCompletion({
    required String gubId,
    required String eventId,
    required String userId,
    required String senderName,
    required bool completed,
  }) => _db.runTransaction((tx) async {
    final ref = _events(gubId).doc(eventId);
    final snap = await tx.get(ref);
    if (!snap.exists) throw StateError('Event not found.');
    final data = snap.data()!;
    if (data['status'] != 'active') return false;
    final assignments = List<Map<String, dynamic>>.from(
      (data['assignments'] as List).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final index = assignments.indexWhere((e) => e['userId'] == userId);
    if (index < 0) throw StateError('You are not assigned to this event.');
    assignments[index]['isCompleted'] = completed;
    assignments[index]['completedAt'] = completed ? Timestamp.now() : null;
    final allDone =
        assignments.isNotEmpty &&
        assignments.every((e) => e['isCompleted'] == true);
    final completedAt = allDone ? Timestamp.now() : null;
    tx.update(ref, {
      'assignments': assignments,
      'status': allDone ? 'completed' : 'active',
      'completedAt': completedAt,
    });

    if (allDone) {
      final recipientIds = <String>{
        if (data['createdBy'] is String) data['createdBy'] as String,
        for (final assignment in assignments)
          if (assignment['userId'] is String) assignment['userId'] as String,
      }..removeWhere((id) => id.isEmpty || id == userId);

      if (recipientIds.isNotEmpty) {
        final notificationId = 'organized_event_completed_$eventId';
        final notification = NotificationModel(
          notificationId: notificationId,
          title: 'Event completed',
          body: '"${data['title'] ?? 'Event'}" has been completed.',
          type: 'organized_event_completed',
          senderId: userId,
          senderName: senderName,
          createdAt: completedAt!,
          readBy: [userId],
          data: {
            'module': 'organized_events',
            'gubId': gubId,
            'eventId': eventId,
            'organizedEventId': eventId,
            'recipientIds': recipientIds.toList(growable: false),
          },
        );
        final notificationReference = _db
            .collection('gubs')
            .doc(gubId)
            .collection('notifications')
            .doc(notificationId);
        tx.set(notificationReference, notification.toFirestore());
      }
    }

    return allDone;
  });

  String? _nonEmptyString(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }
}
