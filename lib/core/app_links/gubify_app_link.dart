sealed class GubifyAppLink {
  const GubifyAppLink();

  String get deduplicationKey;
}

final class PrivateGubInviteLink extends GubifyAppLink {
  final String canonicalCode;
  final String visibleCode;

  const PrivateGubInviteLink({
    required this.canonicalCode,
    required this.visibleCode,
  });

  @override
  String get deduplicationKey => 'join:$canonicalCode';

  @override
  bool operator ==(Object other) =>
      other is PrivateGubInviteLink &&
      other.canonicalCode == canonicalCode &&
      other.visibleCode == visibleCode;

  @override
  int get hashCode => Object.hash(canonicalCode, visibleCode);
}

final class CommunityAppLink extends GubifyAppLink {
  final String slug;

  const CommunityAppLink({required this.slug});

  @override
  String get deduplicationKey => 'community:$slug';

  @override
  bool operator ==(Object other) =>
      other is CommunityAppLink && other.slug == slug;

  @override
  int get hashCode => slug.hashCode;
}
