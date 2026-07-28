import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gub_event_model.dart';

class GubEventRepository {
  GubEventRepository._();
  static final instance = GubEventRepository._();
  final _db = FirebaseFirestore.instance;
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
  Future<void> create(GubEventModel event) =>
      _events(event.gubId).doc(event.eventId).set(event.toFirestore());
  Future<bool> setOwnCompletion({
    required String gubId,
    required String eventId,
    required String userId,
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
    tx.update(ref, {
      'assignments': assignments,
      'status': allDone ? 'completed' : 'active',
      'completedAt': allDone ? Timestamp.now() : null,
    });
    return allDone;
  });
}
