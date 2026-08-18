class CommunityNameAlreadyExistsException implements Exception {
  final String communityId;

  const CommunityNameAlreadyExistsException(this.communityId);
}
