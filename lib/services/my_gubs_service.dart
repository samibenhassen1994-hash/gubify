import 'package:firebase_auth/firebase_auth.dart';

import '../modules/community/models/community_model.dart';
import '../modules/community/services/community_service.dart';
import '../repositories/gub_repository.dart';

class MyGubsService {
  MyGubsService._();

  static final MyGubsService instance = MyGubsService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Map<String, dynamic>>> privateGubsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error(StateError("You must be signed in to view Gubs."));
    }
    return GubRepository.instance.userGubsStream(user.uid);
  }

  Stream<List<CommunityMembershipModel>> communitiesStream() =>
      CommunityService.instance.myCommunityMembershipsStream();

  Future<bool> isCurrentUserMember(String gubId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    return GubRepository.instance.isMember(gubId: gubId, userId: user.uid);
  }

  Future<void> removeStalePrivateGubReference(String gubId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await GubRepository.instance.removeUserGubReference(
      gubId: gubId,
      userId: user.uid,
    );
  }
}
