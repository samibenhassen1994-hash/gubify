import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/gub_message_moderation_report.dart';

class GubMessageModerationRepository {
  GubMessageModerationRepository._();

  static final GubMessageModerationRepository instance =
      GubMessageModerationRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> createReport(GubMessageModerationReport report) {
    final reportReference = _firestore
        .collection('moderationReports')
        .doc(report.reportId);
    final targetReference = _firestore
        .collection('moderationTargets')
        .doc(report.moderationTargetKey);
    return _firestore.runTransaction<bool>((transaction) async {
      final existingReport = await transaction.get(reportReference);
      if (existingReport.exists) return false;

      transaction.set(reportReference, report.toFirestore());
      transaction.set(targetReference, {
        'targetType': report.targetType,
        'targetId': report.targetId,
        'targetNameSnapshot': report.targetNameSnapshot,
        'reportCount': FieldValue.increment(1),
        'lastReportedAt': FieldValue.serverTimestamp(),
        'lastReportId': report.reportId,
      }, SetOptions(merge: true));
      return true;
    });
  }
}
