typedef CommunityImageAssetDeleter = Future<void> Function(String communityId);
typedef CommunityDeletionContinuation = Future<void> Function();

Future<void> runCommunityDeletionAfterMediaCleanup({
  required String communityId,
  required bool hasImage,
  required CommunityImageAssetDeleter deleteImageAsset,
  required CommunityDeletionContinuation continueDeletion,
}) async {
  if (hasImage) {
    await deleteImageAsset(communityId);
  }
  await continueDeletion();
}
