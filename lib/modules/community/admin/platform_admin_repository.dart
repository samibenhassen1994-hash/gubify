import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'platform_admin_service.dart';

class PlatformAdminRepository {
  Stream<PlatformAdminIdentity?> identities() async* {
    yield* FirebaseAuth.instance.userChanges().map(
      (user) => user == null
          ? null
          : PlatformAdminIdentity(uid: user.uid, isAnonymous: user.isAnonymous),
    );
  }

  Stream<bool> watchActive(String uid) => FirebaseFirestore.instance
      .collection('platformAdmins')
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .map((doc) => !doc.metadata.isFromCache && doc.data()?['active'] == true);

  Future<bool> readActive(String uid) async {
    final document = await FirebaseFirestore.instance
        .collection('platformAdmins')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    return document.data()?['active'] == true;
  }
}
