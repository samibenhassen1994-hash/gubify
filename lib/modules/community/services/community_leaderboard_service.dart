import '../models/community_leaderboard_model.dart';
import '../repositories/community_leaderboard_repository.dart';

class CommunityLeaderboardService {
  CommunityLeaderboardService({CommunityLeaderboardRepository? repository})
    : _repository = repository ?? CommunityLeaderboardRepository.instance;

  static final instance = CommunityLeaderboardService();
  static const pageSize = 5;
  static const maximumEntries = 10;

  final CommunityLeaderboardRepository _repository;

  Future<CommunityLeaderboardPage> loadTopLevel({
    required String communityId,
    Object? after,
    int limit = pageSize,
  }) => _repository.loadTopLevel(
    communityId: communityId,
    after: after,
    limit: limit.clamp(1, pageSize),
  );

  Future<CommunityLeaderboardPage> loadTopAnswers({
    required String communityId,
    Object? after,
    int limit = pageSize,
  }) => _repository.loadTopAnswers(
    communityId: communityId,
    after: after,
    limit: limit.clamp(1, pageSize),
  );
}
