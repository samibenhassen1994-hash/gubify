class CommunityLeaderboardMember {
  const CommunityLeaderboardMember({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    required this.xp,
    this.bestAnswerCount = 0,
  });

  final String userId;
  final String displayName;
  final String? photoUrl;
  final int xp;
  final int bestAnswerCount;

  CommunityLeaderboardMember withXp(int value) => CommunityLeaderboardMember(
    userId: userId,
    displayName: displayName,
    photoUrl: photoUrl,
    xp: value,
    bestAnswerCount: bestAnswerCount,
  );
}

class CommunityLeaderboardPage {
  const CommunityLeaderboardPage({
    required this.members,
    this.nextCursor,
    this.hasMore = false,
  });

  final List<CommunityLeaderboardMember> members;
  final Object? nextCursor;
  final bool hasMore;
}
