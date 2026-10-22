typedef ResolveCommunityId = Future<String?> Function(String slug);
typedef OpenResolvedCommunity = Future<void> Function(String communityId);
typedef ShowCommunityUnavailable = Future<void> Function();

class CommunityAppLinkHandler {
  final ResolveCommunityId resolveCommunityId;
  final OpenResolvedCommunity openCommunity;
  final ShowCommunityUnavailable showUnavailable;

  const CommunityAppLinkHandler({
    required this.resolveCommunityId,
    required this.openCommunity,
    required this.showUnavailable,
  });

  Future<void> open(String slug) async {
    final communityId = await resolveCommunityId(slug);
    if (communityId == null) {
      await showUnavailable();
      return;
    }
    await openCommunity(communityId);
  }
}
