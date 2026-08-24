import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_report_model.dart';

class CommunityModerationRepository {
  CommunityModerationRepository._();

  static final CommunityModerationRepository instance =
      CommunityModerationRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> createReport(CommunityModerationReport report) {
    final reportReference = _firestore
        .collection('moderationReports')
        .doc(report.reportId);
    final targetReference = _firestore
        .collection('moderationTargets')
        .doc(report.moderationTargetKey);
    return _firestore.runTransaction<bool>((transaction) async {
      final existingReport = await transaction.get(reportReference);
      if (existingReport.exists) return false;

      final existingTarget = await transaction.get(targetReference);

      transaction.set(reportReference, report.toFirestore());
      if (existingTarget.exists) {
        final reportCount =
            (existingTarget.data()?['reportCount'] as num?)?.toInt() ?? 0;
        transaction.update(targetReference, {
          'targetNameSnapshot': report.moderationTargetNameSnapshot,
          'reportCount': reportCount + 1,
          'lastReportedAt': FieldValue.serverTimestamp(),
          'lastReportId': report.reportId,
        });
      } else {
        transaction.set(targetReference, {
          'targetType': report.targetType,
          'targetId': report.targetId,
          'targetNameSnapshot': report.moderationTargetNameSnapshot,
          'reportCount': 1,
          'firstReportedAt': FieldValue.serverTimestamp(),
          'lastReportedAt': FieldValue.serverTimestamp(),
          'lastReportId': report.reportId,
        });
      }
      return true;
    });
  }
}
