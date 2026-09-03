import 'package:firebase_auth/firebase_auth.dart';

import '../models/community_ask_model.dart';
import '../repositories/community_profile_ask_history_repository.dart';

typedef CommunityProfileAskPageLoad =
    Future<CommunityProfileAsksPage> Function({
      required String viewerId,
      required String targetUserId,
      required CommunityAskStatus status,
      required Map<String, String> knownCommunities,
      CommunityProfileAsksCursor? after,
    });

class CommunityProfileAskHistoryService {
  CommunityProfileAskHistoryService({
    String? Function()? currentUserId,
    CommunityProfileAskPageLoad? loadPage,
  }) : _currentUserId =
           currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _loadPage =
           loadPage ?? CommunityProfileAskHistoryRepository.instance.loadPage;

  static final instance = CommunityProfileAskHistoryService();

  final String? Function() _currentUserId;
  final CommunityProfileAskPageLoad _loadPage;

  Future<CommunityProfileAsksPage> loadPage({
    required String targetUserId,
    required CommunityAskStatus status,
    required Map<String, String> knownCommunities,
    CommunityProfileAsksCursor? after,
  }) {
    final viewerId = _currentUserId();
    if (viewerId == null) {
      throw StateError('You must be signed in to view Community Asks.');
    }
    return _loadPage(
      viewerId: viewerId,
      targetUserId: targetUserId,
      status: status,
      knownCommunities: knownCommunities,
      after: after,
    );
  }
}
