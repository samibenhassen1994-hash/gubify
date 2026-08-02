import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/models/creation_availability.dart';

class CreationCooldownRepository {
  CreationCooldownRepository._();

  static final CreationCooldownRepository instance =
      CreationCooldownRepository._();

  static const Duration cooldownDuration = creationCooldownDuration;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> reference({
    required String gubId,
    required String creatorId,
    required CreationModuleType moduleType,
  }) {
    return _firestore
        .collection('gubs')
        .doc(gubId)
        .collection('creationCooldowns')
        .doc('${creatorId}_${moduleType.firestoreValue}');
  }

  Future<CreationCooldown?> get({
    required String gubId,
    required String creatorId,
    required CreationModuleType moduleType,
  }) async {
    final document = await reference(
      gubId: gubId,
      creatorId: creatorId,
      moduleType: moduleType,
    ).get();
    return _fromDocument(document);
  }

  Stream<CreationCooldown?> stream({
    required String gubId,
    required String creatorId,
    required CreationModuleType moduleType,
  }) {
    return reference(
      gubId: gubId,
      creatorId: creatorId,
      moduleType: moduleType,
    ).snapshots().map(_fromDocument);
  }

  void setInTransaction({
    required Transaction transaction,
    required String gubId,
    required String creatorId,
    required CreationModuleType moduleType,
    required String deletedItemId,
    required String deletedBy,
    required Timestamp availableAt,
  }) {
    transaction.set(
      reference(gubId: gubId, creatorId: creatorId, moduleType: moduleType),
      {
        'creatorId': creatorId,
        'moduleType': moduleType.firestoreValue,
        'deletedItemId': deletedItemId,
        'deletedBy': deletedBy,
        'deletedAt': FieldValue.serverTimestamp(),
        'availableAt': availableAt,
      },
    );
  }

  CreationCooldown? _fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (!document.exists || data == null) return null;

    final creatorId = data['creatorId'];
    final moduleValue = data['moduleType'];
    final availableAt = data['availableAt'];
    if (creatorId is! String ||
        creatorId.isEmpty ||
        moduleValue is! String ||
        availableAt is! Timestamp) {
      return null;
    }

    CreationModuleType? moduleType;
    for (final value in CreationModuleType.values) {
      if (value.firestoreValue == moduleValue) {
        moduleType = value;
        break;
      }
    }
    if (moduleType == null) return null;

    return CreationCooldown(
      creatorId: creatorId,
      moduleType: moduleType,
      deletedItemId: data['deletedItemId'] as String? ?? '',
      deletedBy: data['deletedBy'] as String? ?? '',
      deletedAt: data['deletedAt'] as Timestamp?,
      availableAt: availableAt,
    );
  }
}
