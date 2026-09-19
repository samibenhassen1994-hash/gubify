import '../models/community_leaderboard_model.dart';
import '../repositories/global_best_answer_ranking_repository.dart';

class GlobalBestAnswerRankingService {
  GlobalBestAnswerRankingService({
    GlobalBestAnswerRankingRepository? repository,
  }) : _repository = repository ?? GlobalBestAnswerRankingRepository.instance;
  static final instance = GlobalBestAnswerRankingService();
  static const pageSize = 10;
  static const maximumEntries = 100;
  final GlobalBestAnswerRankingRepository _repository;

  Future<CommunityLeaderboardPage> loadPage({
    Object? after,
    int limit = pageSize,
  }) => _repository.loadPage(after: after, limit: limit.clamp(1, pageSize));
}
