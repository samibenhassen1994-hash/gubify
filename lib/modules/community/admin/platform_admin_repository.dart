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
}
